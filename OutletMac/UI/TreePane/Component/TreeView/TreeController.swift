//
//  TreeController.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-01.
//
import SwiftUI
import DequeModule

/**
 PROTOCOL TreeControllable
 */
protocol TreeControllable: HasLifecycle {
  var app: OutletAppProtocol { get }
  var tree: DisplayTree { get }
  var swiftTreeState: SwiftTreeState { get }
  var swiftFilterState: SwiftFilterState { get }

  var treeView: TreeNSViewController? { get set }
  var displayStore: DisplayStore { get }
  var treeActions: TreeActions { get }
  var contextMenu: TreeContextMenu { get }

  // Convenience getters - see extension below
  var backend: OutletBackend { get }
  var dispatcher: SignalDispatcher { get }
  var treeID: TreeID { get }
  var treeLoadState: TreeLoadState { get }

  var canChangeRoot: Bool { get }
  var allowsMultipleSelection: Bool { get }
  var expandContractListenersEnabled: Bool { get set }

  var dispatchListener: DispatchListener { get }

  func updateDisplayTree(to newTree: DisplayTree) throws
  func requestTreeLoad() throws
  func generateCheckedRowList() throws -> [SPIDNodePair]
  func setChecked(_ guid: GUID, _ isChecked: Bool) throws

  func connectTreeView(_ treeView: TreeNSViewController)
  func clearTreeAndDisplayMsg(_ msg: String, _ iconID: IconID)
  func appendEphemeralNode(_ parentSPID: SPID, _ nodeName: String, _ iconID: IconID, reloadParent: Bool)

  func reportError(_ title: String, _ errorMsg: String)
  func reportException(_ title: String, _ error: Error)
}

/**
 Add convenience methods for commonly used sub-member objects
 */
extension TreeControllable {
  var backend: OutletBackend {
    get {
      return app.backend
    }
  }

  var dispatcher: SignalDispatcher {
    get {
      return app.dispatcher
    }
  }

  var treeID: TreeID {
    get {
      return self.tree.treeID
    }
  }
}

/**
 CLASS TreeController

 Serves as the controller for the entire tree panel for a single UI tree.

 Equivalent to "TreeController" in the Python/GTK3 version of the app, but renamed in the Mac version so as not
 to be confused with the TreeNSViewController (which is an AppKit controller for NSOutlineView)
 */
class TreeController: TreeControllable {
  var app: OutletAppProtocol
  var tree: DisplayTree
  var dispatchListener: DispatchListener
  let displayStore: DisplayStore = DisplayStore()
  let treeActions: TreeActions = TreeActions()
  let contextMenu: TreeContextMenu = TreeContextMenu()
  var treeView: TreeNSViewController? = nil

  // State variables:
  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState
  var treeLoadState: TreeLoadState = .NOT_LOADED
  var canChangeRoot: Bool
  var allowsMultipleSelection: Bool
  var expandContractListenersEnabled: Bool = true
  private var enableNodeUpdateSignals: Bool = false
  // workaround for race condition, in case we are ready to populate before the UI is ready
  private var readyToPopulate: Bool = false

  private lazy var filterTimer = HoldOffTimer(FILTER_APPLY_DELAY_MS, self.fireFilterTimer)

  private let dq = DispatchQueue(label: "TreeController-SerialQueue") // custom dispatch queues are serial by default

  init(app: OutletAppProtocol, tree: DisplayTree, filterCriteria: FilterCriteria, canChangeRoot: Bool, allowsMultipleSelection: Bool) throws {
    self.app = app
    self.tree = tree
    self.swiftTreeState = try SwiftTreeState.from(tree)
    self.swiftFilterState = SwiftFilterState.from(filterCriteria)
    self.dispatchListener = self.app.dispatcher.createListener(tree.treeID)
    self.canChangeRoot = canChangeRoot
    self.allowsMultipleSelection = allowsMultipleSelection
  }

  func start() throws {
    NSLog("DEBUG [\(self.treeID)] Controller start() called")
    displayStore.con = self
    treeActions.con = self
    contextMenu.con = self

    self.subscribeToSignals(treeID)

    self.swiftFilterState.onChangeCallback = self.onFilterChanged
  }

  func shutdown() throws {
    NSLog("DEBUG [\(self.treeID)] Controller shutdown() called")
    self.dispatchListener.unsubscribeAll()

    self.dispatcher.sendSignal(signal: .DEREGISTER_DISPLAY_TREE, senderID: self.treeID)
  }

  func reattachListeners(_ newTreeID: TreeID) {
    NSLog("DEBUG [\(self.treeID)] reattachListeners() called")
    self.dispatchListener.unsubscribeAll()

    self.dispatchListener = self.app.dispatcher.createListener(newTreeID)
    self.subscribeToSignals(newTreeID)
  }

  private func subscribeToSignals(_ treeID: TreeID) {
    self.dispatchListener.subscribe(signal: .TREE_LOAD_STATE_UPDATED, self.onTreeLoadStateUpdated, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .DISPLAY_TREE_CHANGED, self.onDisplayTreeChanged, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .CANCEL_ALL_EDIT_ROOT, self.onEditingRootCancelled)
    self.dispatchListener.subscribe(signal: .CANCEL_OTHER_EDIT_ROOT, self.onEditingRootCancelled, blacklistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .STATS_UPDATED, self.onDirStatsUpdated, whitelistSenderID: treeID)

    self.dispatchListener.subscribe(signal: .NODE_UPSERTED, self.onNodeUpserted, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .NODE_REMOVED, self.onNodeRemoved, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .SUBTREE_NODES_CHANGED, self.onSubtreeNodesChanged, whitelistSenderID: treeID)

    self.dispatchListener.subscribe(signal: .DOWNLOAD_FROM_GDRIVE_DONE, self.onGDriveDownloadDone, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .SET_SELECTED_ROWS, self.onSetSelectedRows, whitelistSenderID: treeID)
  }

  public func updateDisplayTree(to newTree: DisplayTree) throws {
    NSLog("DEBUG [\(self.treeID)] Got new display tree (rootPath=\(newTree.rootPath), state=\(newTree.state))")
    self.dq.sync {
      if newTree.treeID != self.tree.treeID {
        NSLog("INFO  [\(self.treeID)] Changing treeID to \(newTree.treeID)")
        self.treeView = nil
        self.app.reregisterTreePanelController(oldTreeID: self.tree.treeID, newTreeID: newTree.treeID, self)
        self.reattachListeners(newTree.treeID)
      }
      self.tree = newTree
      self.treeLoadState = .NOT_LOADED
    }

    DispatchQueue.main.async {
      do {
        try self.swiftTreeState.updateFrom(self.tree)
      } catch {
        self.reportException("Failed to update Swift tree state", error)
      }
    }

    try self.requestTreeLoad()
  }

  func requestTreeLoad() throws {
    self.dq.async {
      do {
        NSLog("INFO [\(self.treeID)] Requesting start subtree load")

        self.clearTreeAndDisplayMsg(LOADING_MESSAGE, .ICON_LOADING)

        // this calls to the backend to do the load, which will eventually (with luck) come back to call onTreeLoadStateUpdated()
        self.enableNodeUpdateSignals = false
        try self.backend.startSubtreeLoad(treeID: self.treeID)
      } catch {
        NSLog("ERROR [\(self.treeID)] Failed to load tree: \(error)")
        let errorMsg: String = "\(error)" // ew, heh
        self.reportError("Failed to load tree", errorMsg)
      }
    }
  }

  // Should be called by TreeNSViewController
  func connectTreeView(_ treeView: TreeNSViewController) {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG [\(self.treeID)] connectTreeView() starting")
    }

    NSLog("INFO  [\(self.treeID)] Connecting TreeView to TreeController")
    self.treeView = treeView

    if self.readyToPopulate {
      self.populateTreeView()
    } else {
      NSLog("DEBUG [\(self.treeID)] readyToPopulate is false")
    }

    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG [\(self.treeID)] connectTreeView() done")
    }
  }

  /**
   NOTE: Must run inside DispatchQueue.main!
   */
  private func clearModelAndTreeView() {
    assert(DispatchQueue.isExecutingIn(.main))

    // Clear display store & TreeView (which draws from display store)
    NSLog("DEBUG [\(treeID)] Clearing model and tree view")
    self.displayStore.putRootChildList(self.tree.rootSN, [])
    self.treeView?.reloadData()
  }

  /**
   NOTE: Executes SYNC in DispatchQueue, NOT async. Need to make sure this executes prior to whatever replaces it!
   */
  func clearTreeAndDisplayMsg(_ msg: String, _ iconID: IconID) {
    self.dq.async {
      DispatchQueue.main.sync {
        NSLog("DEBUG [\(self.treeID)] Clearing tree and displaying msg: '\(msg)'")
        self.clearModelAndTreeView()
        self.appendEphemeralNode(self.tree.rootSPID, msg, iconID, reloadParent: true)
      }
    }
  }

  /**
   Executes async in App-SerialQueue, to ensure serial execution. This will catch and report exceptions.
   */
  private func populateTreeView() {

    NSLog("DEBUG [\(treeID)] populateTreeView(): clearing tree and displaying loading msg")
    clearTreeAndDisplayMsg(LOADING_MESSAGE, .ICON_LOADING)

    self.dq.async {
      do {
        try self.populateTreeView_inner()
      } catch {
        self.reportException("Failed to populate tree", error)
      }
    }
  }

  private func populateTreeView_inner() throws {
    NSLog("DEBUG [\(treeID)] Starting populateTreeView()")
    guard self.treeView != nil else {
      NSLog("DEBUG [\(treeID)] populateTreeView(): TreeView is nil. Setting readyToPopulate to true")
      readyToPopulate = true
      return
    }
    readyToPopulate = false

    if !self.tree.state.rootExists {
      NSLog("INFO  [\(treeID)] populateTreeView(): rootExists==false; bailling")
      clearTreeAndDisplayMsg("Tree does not exist", .ICON_ALERT)
      return
    }

    let populateStartTimeMS = DispatchTime.now()

    let rows: RowsOfInterest
    do {
      rows = try self.app.backend.getRowsOfInterest(treeID: self.treeID)
      NSLog("DEBUG [\(treeID)] Got expanded=\(rows.expanded), selected=\(rows.selected)")
    } catch {
      reportException("Failed to fetch expanded node list", error)
      rows = RowsOfInterest() // non-fatal error
    }

    var queue = Deque<SPIDNodePair>()

    do {
      let topLevelSNList: [SPIDNodePair] = try self.tree.getChildListForRoot()
      NSLog("DEBUG [\(self.treeID)] populateTreeView(): Got \(topLevelSNList.count) top-level nodes for root (\(self.tree.rootSPID.guid))")

      self.displayStore.putRootChildList(self.tree.rootSN, topLevelSNList)
      if topLevelSNList.count == 0 {
        // clear loading node
        NSLog("INFO  [\(self.treeID)] populateTreeView(): no nodes in tree")
        DispatchQueue.main.async {
          self.clearModelAndTreeView()
        }
        return
      }
      for sn in topLevelSNList {
        queue.append(sn)
      }
    } catch OutletError.maxResultsExceeded(let actualCount) {
      // When both calls below have separate DispatchQueue WorkItems, sometimes nothing shows up.
      // Is it possible the WorkItems can arrive out of order? Need to research this.
      NSLog("DEBUG [\(self.treeID)] populateTreeView(): Max results exceeded (actualCount=\(actualCount)")
      self.clearTreeAndDisplayMsg("ERROR: too many items to display (\(actualCount))", .ICON_ALERT)
      return
    }

    // We populate each expanded row in the DisplayStore first, and then reload the tree once it's fully populated.
    // This way we avoid loading in fits and spurts, and it looks cleaner
    var toExpandInOrder: [GUID] = []
    while !queue.isEmpty {

      let sn = queue.popFirst()!
      let guid = sn.spid.guid
      if sn.node.isDir && rows.expanded.contains(guid) {
        // only expand rows which are actually present:
        NSLog("DEBUG [\(treeID)] populateTreeView(): Will expand row: \(guid)")
        toExpandInOrder.append(guid)
        do {
          let childSNList: [SPIDNodePair] = try self.tree.getChildList(sn.spid)
          NSLog("DEBUG [\(treeID)] populateTreeView(): Got \(childSNList.count) child nodes for parent \(sn.spid)")

          self.displayStore.putChildList(guid, childSNList)
          for sn in childSNList {
            queue.append(sn)
          }

        } catch OutletError.maxResultsExceeded(let actualCount) {
          // append err node and continue
          DispatchQueue.main.async {
            self.appendEphemeralNode(sn.spid, "ERROR: too many items to display (\(actualCount))", .ICON_ALERT, reloadParent: false)
          }
        }
      }
    }

    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.treeID)] populateTreeView(): reloading entire tree")
      self.treeView?.reloadData()

      self.treeView?.expand(toExpandInOrder, isAlreadyPopulated: true)

      self.treeView!.selectGUIDList(rows.selected)

      let timeElapsed = populateStartTimeMS.distance(to: DispatchTime.now())
      NSLog("INFO  [\(self.treeID)] populateTreeView() completed in \(timeElapsed.toString())")
      self.dispatcher.sendSignal(signal: .POPULATE_UI_TREE_DONE, senderID: self.treeID)
    }
  }

  // MUST RUN INSIDE MAIN DQ
  func appendEphemeralNode(_ parentSPID: SPID, _ nodeName: String, _ iconID: IconID, reloadParent: Bool) {
    assert(DispatchQueue.isExecutingIn(.main))

    let ephemeralNode = EphemeralNode(nodeName, parent: parentSPID, iconID)
    let ephemeralSN = ephemeralNode.toSN()
    let parentGUID = parentSPID.guid

    NSLog("DEBUG [\(self.treeID)] Appending ephemeral node to parent \(parentGUID): guid=\(ephemeralSN.spid.guid) name='\(nodeName)' reloadParent=\(reloadParent)")

    // yeah, make sure we put this inside the main DQ or weird race conditions result:
    if parentGUID == self.tree.rootSPID.guid {
      self.displayStore.putRootChildList(self.tree.rootSN, [ephemeralSN])
    } else {
      self.displayStore.putChildList(parentGUID, [ephemeralSN])
    }

    if reloadParent {
      self.treeView?.reloadItem(parentGUID, reloadChildren: true)
    }
    NSLog("DEBUG [\(self.treeID)] Appended ephemeral node to parent \(parentGUID): guid=\(ephemeralSN.spid.guid) name='\(nodeName)' reloadParent=\(reloadParent)")
  }

  private func updateStatusBarMsg(_ statusBarMsg: String) {
    NSLog("DEBUG [\(self.treeID)] Updating status bar msg with content: \"\(statusBarMsg)\"")
    assert(DispatchQueue.isExecutingIn(.main))
    self.swiftTreeState.statusBarMsg = statusBarMsg
  }

  func setChecked(_ guid: GUID, _ isChecked: Bool) throws {
    guard let sn = self.displayStore.getSN(guid) else {
      self.reportError("Internal Error", "Could not toggle checkbox: could not find SN in DisplayStore for GUID \(guid)")
      return
    }
    if sn.node.isEphemeral {
      return
    }

    // What a mouthful. At least we are handling the bulk of the work in one batch:
    self.displayStore.updateCheckboxStateForSameLevelAndBelow(guid, isChecked, self.treeID)
    // Now update all of those in the UI:
    self.treeView?.reloadItem(guid, reloadChildren: true)

    /*
     3. Ancestors: need to update all direct ancestors, but take into account all of the children of each.
     */
    NSLog("DEBUG [\(treeID)] setChecked(): Checking ancestors of \(guid)")
    var ancestorGUID: GUID = guid
    while true {
      ancestorGUID = self.displayStore.getParentGUID(ancestorGUID)!
      NSLog("DEBUG [\(treeID)] setChecked(): Next higher ancestor=\(ancestorGUID)")
      if ancestorGUID == self.tree.rootSPID.guid {
        break
      }
      var hasChecked = false
      var hasUnchecked = false
      var hasMixed = false
      for childGUID in self.displayStore.getChildGUIDList(ancestorGUID) {
        if self.displayStore.isCheckboxChecked(childGUID) {
          hasChecked = true
        } else {
          hasUnchecked = true
        }
        hasMixed = hasMixed || self.displayStore.isCheckboxMixed(childGUID)
      }
      let isChecked = hasChecked && !hasUnchecked && !hasMixed
      let isMixed = hasMixed || (hasChecked && hasUnchecked)
      let ancestorSN = self.displayStore.getSN(ancestorGUID)
      NSLog("DEBUG [\(treeID)] setChecked(): Ancestor=\(ancestorGUID) hasChecked=\(hasChecked) hasUnchecked=\(hasUnchecked) hasMixed=\(hasMixed) => isChecked=\(isChecked) isMixed=\(isMixed)")
      self.setCheckedStateForSingleNode(ancestorSN!, isChecked: isChecked, isMixed: isMixed)
    }
  }

  private func setCheckedStateForSingleNode(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    let guid = sn.spid.guid
    NSLog("DEBUG [\(treeID)] setChecked(): Updating checkbox state of: \(guid) (\(sn.spid)) => \(isChecked)/\(isMixed)")

    // Update model here:
    self.displayStore.updateCheckedStateTracking(guid, isChecked: isChecked, isMixed: isMixed)

    // Now update the node in the UI:
    self.treeView!.reloadItem(guid, reloadChildren: false)
  }

  /** Returns a list which contains the nodes of the items which are currently checked by the user
  (including any rows which may not be visible in the UI due to being collapsed). This will be a subset of the ChangeDisplayTree currently
  being displayed. Includes file nodes only, with the exception of MKDIR nodes.

  This method assumes that we are a ChangeTree and thus returns instances of GUID. We don't try to do any fancy logic to filter out
  CategoryNodes, existing directories, or other non-change nodes; we'll let the backend handle that. We simply return each of the GUIDs which
  have check boxes in the GUI (1-to-1 in count)

  Algorithm:
      Iterate over display nodes. Start with top-level nodes.
    - If row is checked, add it to checked_queue.
      Each node added to checked_queue will be added to the returned list along with all its descendants.
    - If row is unchecked, ignore it.
    - If row is inconsistent, add it to mixed_queue. Each of its descendants will be examined and have these rules applied recursively.
  */
  func generateCheckedRowList() throws -> [SPIDNodePair] {
    let (checkedNodeSet, mixedNodeSet) = self.displayStore.getCheckedAndMixedRows()

    NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Checked nodes: \(checkedNodeSet). Mixed nodes: \(mixedNodeSet)")

    var checkedRowList: [SPIDNodePair] = []

    var checkedQueue = Deque<SPIDNodePair>()
    var mixedQueue = Deque<SPIDNodePair>()

    assert(self.tree.hasCheckboxes, "Tree does not have checkboxes. Is this a ChangeTree? \(self.tree.state)")

    mixedQueue.append(self.tree.rootSN)

    NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Examining mixed-state node list...")

    while !mixedQueue.isEmpty {
      let mixedDirSN = mixedQueue.popFirst()!
      if SUPER_DEBUG_ENABLED {
        NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Examining next mixed-state dir: \(mixedDirSN.spid)")
      }
      assert(mixedDirSN.node.isDir, "Expected a dir-type node: \(mixedDirSN.node)")  // only dir nodes can be mixed

      // Check each child of a mixed dir for checked or mixed status.
      // We will iterate through the master cache, which is necessary since we may have implicitly checked nodes which are not visible in the UI.
      for childSN in try self.tree.getChildList(mixedDirSN.spid) {
        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Examining child of mixed-state dir: \(childSN.spid)")
        }
        if checkedNodeSet.contains(childSN.spid.guid) {
          if SUPER_DEBUG_ENABLED {
            NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Adding child to checkedQueue: \(childSN.spid)")
          }
          checkedQueue.append(childSN)
        } else if mixedNodeSet.contains(childSN.spid.guid) {
          if SUPER_DEBUG_ENABLED {
            NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Adding child to mixed list: \(childSN.spid)")
          }
          mixedQueue.append(childSN)
        }
      }
    }

    NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Examining checkedQueue...")

    // Whitelist contains nothing but trees full of checked items
    while !checkedQueue.isEmpty {
      let chosenSN = checkedQueue.popFirst()!
      if SUPER_DEBUG_ENABLED {
        NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Popped next in checkedQueue. Adding to CHECKED list: \(chosenSN.spid.guid) \(chosenSN.spid)")
      }

      checkedRowList.append(chosenSN)

      // Drill down into all descendants of nodes in the checkedQueue.
      if chosenSN.node.isDir {
        for childSN in try self.tree.getChildList(chosenSN.spid) {
          if SUPER_DEBUG_ENABLED {
            NSLog("DEBUG [\(treeID)] generateCheckedRowList(): Adding node to checkedQueue: \(chosenSN.spid.guid)")
          }
          checkedQueue.append(childSN)
        }
      }
    }

    NSLog("DEBUG [\(treeID)] generateCheckedRowList(): returning \(checkedRowList.count) checked items")
    return checkedRowList
  }

  // Util: error reporting
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func reportError(_ title: String, _ errorMsg: String) {
    // See listener in OutletAppProtocol
    NSLog("DEBUG [\(self.treeID)] Reporting local error: title='\(title)' error='\(errorMsg)'")
    self.dispatcher.sendSignal(signal: .ERROR_OCCURRED, senderID: treeID, ["msg": title, "secondary_msg": errorMsg])
  }

  func reportException(_ title: String, _ error: Error) {
    let errorMsg: String = "\(error)" // ew, heh
    reportError(title, errorMsg)
  }


  // DispatchListener callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func onTreeLoadStateUpdated(_ senderID: SenderID, _ propDict: PropDict) throws {
    let treeLoadState = try propDict.get("tree_load_state") as! TreeLoadState
    let statusBarMsg = try propDict.getString("status_msg")
    let dirStatsDictByGUID = try propDict.get("dir_stats_dict_by_guid") as! [GUID:DirectoryStats]
    let dirStatsDictByUID = try propDict.get("dir_stats_dict_by_uid") as! [UID:DirectoryStats]

    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.treeID)] Got signal: \(Signal.TREE_LOAD_STATE_UPDATED) with state=\(treeLoadState), status_msg='\(statusBarMsg)'")

      self.treeLoadState = treeLoadState

      self.updateStatusBarMsg(statusBarMsg)

      if dirStatsDictByGUID.count > 0 || dirStatsDictByUID.count > 0 {
        self.displayStore.updateDirStats(dirStatsDictByGUID, dirStatsDictByUID)
        self.treeView?.reloadData()
      }

      switch treeLoadState {
      case .LOAD_STARTED:
        self.enableNodeUpdateSignals = true

        if self.swiftTreeState.isManualLoadNeeded {
          self.swiftTreeState.isManualLoadNeeded = false
        }

        self.populateTreeView()
      default:
        break
      }
    }
  }

  private func onDisplayTreeChanged(_ senderID: SenderID, _ propDict: PropDict) throws {
    let newTree = try propDict.get("tree") as! DisplayTree
    try self.updateDisplayTree(to: newTree)
  }

  private func onEditingRootCancelled(_ senderID: SenderID, _ propDict: PropDict) throws {
    NSLog("DEBUG [\(self.treeID)] Editing cancelled (was: \(self.swiftTreeState.isEditingRoot)); setting rootPath to \(self.tree.rootPath)")
    DispatchQueue.main.async {
      // restore root path to value received from server
      self.swiftTreeState.rootPath = self.tree.rootPath
      self.swiftTreeState.isEditingRoot = false
    }
  }

  private func onDirStatsUpdated(_ senderID: SenderID, _ propDict: PropDict) throws {
    let statusBarMsg = try propDict.getString("status_msg")
    let dirStatsDictByGUID = try propDict.get("dir_stats_dict_by_guid") as! [GUID:DirectoryStats]
    let dirStatsDictByUID = try propDict.get("dir_stats_dict_by_uid") as! [UID:DirectoryStats]

    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.treeID)] Updating dir stats with status msg: \"\(statusBarMsg)\"")
      self.updateStatusBarMsg(statusBarMsg)

      self.displayStore.updateDirStats(dirStatsDictByGUID, dirStatsDictByUID)
      self.treeView?.reloadData()
    }
  }

  private func onNodeUpserted(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring \(Signal.NODE_UPSERTED) signal: signals are disabled")
      return
    }

    let sn = try propDict.get("sn") as! SPIDNodePair
    guard let parentGUID = sn.spid.parentGUID else {
      NSLog("ERROR [\(self.treeID)] Cannot process \(Signal.NODE_UPSERTED) signal: \(sn.spid) is missing parentGUID!")
      return
    }
    NSLog("INFO  [\(self.treeID)] Received \(Signal.NODE_UPSERTED) signal: \(sn.spid) for parent: \(parentGUID)")

    let alreadyPresent: Bool = self.displayStore.putSN(sn, parentGUID: parentGUID)

    DispatchQueue.main.async {
      let reloadTarget: GUID
      if alreadyPresent {
        reloadTarget = sn.spid.guid
        NSLog("DEBUG [\(self.treeID)] Upserted node was already present; reloading: \(reloadTarget)")
      } else {
        reloadTarget = parentGUID
        NSLog("DEBUG [\(self.treeID)] Upserted node is new; reloading its parent: \(reloadTarget)")
      }
      self.treeView?.reloadItem(reloadTarget, reloadChildren: true)
    }
  }

  private func onNodeRemoved(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring \(Signal.NODE_REMOVED) signal: signals are disabled")
      return
    }

    let sn = try propDict.get("sn") as! SPIDNodePair
    guard let parentGUID = sn.spid.parentGUID else {
      NSLog("ERROR [\(self.treeID)] Cannot process \(Signal.NODE_REMOVED) signal: \(sn.spid) is missing parentGUID!")
      return
    }
    NSLog("DEBUG [\(self.treeID)] Received \(Signal.NODE_REMOVED) signal: \(sn.spid) (GUID=\(sn.spid.guid), parent_GUID=\(parentGUID))")

    if self.displayStore.removeSN(sn.spid.guid) {
      DispatchQueue.main.async {
        if parentGUID == self.tree.rootSPID.guid {
          NSLog("DEBUG [\(self.treeID)] Parent of removed node is root node!")
        }
        self.treeView?.reloadItem(parentGUID, reloadChildren: true)
      }
    }
  }

  private func onSubtreeNodesChanged(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring \(Signal.SUBTREE_NODES_CHANGED) signal: signals are disabled")
      return
    }
    let subtreeRootSPID = try propDict.get("subtree_root_spid") as! SPID
    let upsertedList = try propDict.get("upserted_sn_list") as! [SPIDNodePair]
    let removedList = try propDict.get("removed_sn_list") as! [SPIDNodePair]

    NSLog("DEBUG [\(self.treeID)] Received \(Signal.SUBTREE_NODES_CHANGED) signal with root \(subtreeRootSPID) and \(upsertedList.count) upserts & \(removedList.count) removes")

    for upsertedSN in upsertedList {
      if let parentGUID = upsertedSN.spid.parentGUID {
        _ = self.displayStore.putSN(upsertedSN, parentGUID: parentGUID)
      } else {
        // make this non-lethal
        NSLog("ERROR [\(self.treeID)] While processing \(Signal.SUBTREE_NODES_CHANGED) signal: upserted node \(upsertedSN.spid) is missing parentGUID!")
      }
    }
    for removedSN in removedList {
      _ = self.displayStore.removeSN(removedSN.spid.guid)
    }

    DispatchQueue.main.async {
      // just reload everything for now. Revisit if performance proves to be an issue
      self.treeView?.reloadData()
    }
  }

  private func onGDriveDownloadDone(_ senderID: SenderID, _ propDict: PropDict) throws {
    let filename = try propDict.getString("filename")

    NSLog("DEBUG [\(treeID)] GDrive download complete: opening local file with default app: \(filename)")
    self.treeActions.openLocalFileWithDefaultApp(filename)
  }

  private func onSetSelectedRows(_ senderID: SenderID, _ propDict: PropDict) throws {
    let selectedRows = try propDict.get("selected_rows") as! Set<GUID>
    DispatchQueue.main.async {
      self.treeView!.selectGUIDList(selectedRows)
    }
  }

  // Other callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   The is called when the user makes a filter change in the UI.
  */
  func onFilterChanged(filterState: SwiftFilterState) {
    self.filterTimer.reschedule()
  }

  private func fireFilterTimer() {
    self.dq.async {

      NSLog("DEBUG [\(self.treeID)] Firing timer to update filter via BE")

      do {
        try self.app.backend.updateFilterCriteria(treeID: self.treeID, filterCriteria: self.swiftFilterState.toFilterCriteria())
      } catch {
        NSLog("ERROR [\(self.treeID)] Failed to update filter criteria on the backend: \(error)")
        return
      }

      self.populateTreeView()
    }
  }

}
