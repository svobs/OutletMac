//
//  TreePanelController.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-01.
//
import SwiftUI
import LinkedList

/**
 PROTOCOL TreePanelControllable
 */
protocol TreePanelControllable: HasLifecycle {
  var app: OutletApp { get }
  var tree: DisplayTree { get }
  var swiftTreeState: SwiftTreeState { get }
  var swiftFilterState: SwiftFilterState { get }

  var treeView: TreeViewController? { get set }
  var displayStore: DisplayStore { get }
  var treeActions: TreeActions { get }
  var contextMenu: TreeContextMenu { get }

  // Convenience getters - see extension below
  var backend: OutletBackend { get }
  var dispatcher: SignalDispatcher { get }
  var treeID: TreeID { get }
  var treeLoadState: TreeLoadState { get }

  var canChangeRoot: Bool { get }
  var allowMultipleSelection: Bool { get }

  var dispatchListener: DispatchListener { get }

  func updateDisplayTree(to newTree: DisplayTree) throws
  func requestTreeLoad() throws
  func generateCheckedRowList() throws -> [SPIDNodePair]
  func setChecked(_ guid: GUID, _ isChecked: Bool) throws

  func connectTreeView(_ treeView: TreeViewController)
  func clearTreeAndDisplayLoadingMsg()
  func appendEphemeralNode(_ parentSN: SPIDNodePair?, _ nodeName: String)

  func reportError(_ title: String, _ errorMsg: String)
  func reportException(_ title: String, _ error: Error)
}

/**
 Add convenience methods for commonly used sub-member objects
 */
extension TreePanelControllable {
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
 CLASS TreePanelController

 Serves as the controller for the entire tree panel for a single UI tree.

 Equivalent to "TreeController" in the Python/GTK3 version of the app, but renamed in the Mac version so as not
 to be confused with the TreeViewController (which is an AppKit controller for NSOutlineView)
 */
class TreePanelController: TreePanelControllable {
  var app: OutletApp
  var tree: DisplayTree
  var dispatchListener: DispatchListener
  let displayStore: DisplayStore = DisplayStore()
  let treeActions: TreeActions = TreeActions()
  let contextMenu: TreeContextMenu = TreeContextMenu()

  var treeLoadState: TreeLoadState = .NOT_LOADED
  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

  var treeView: TreeViewController? = nil
  // workaround for race condition, in case we are ready to populate before the UI is ready
  private var readyToPopulate: Bool = false

  var enableNodeUpdateSignals: Bool = false

  var canChangeRoot: Bool
  var allowMultipleSelection: Bool

  private lazy var filterTimer = HoldOffTimer(FILTER_APPLY_DELAY_MS, self.fireFilterTimer)

  init(app: OutletApp, tree: DisplayTree, filterCriteria: FilterCriteria, canChangeRoot: Bool, allowMultipleSelection: Bool) throws {
    self.app = app
    self.tree = tree
    self.swiftTreeState = try SwiftTreeState.from(tree)
    self.dispatchListener = self.app.dispatcher.createListener(tree.treeID)
    self.swiftFilterState = SwiftFilterState.from(filterCriteria)
    self.canChangeRoot = canChangeRoot
    self.allowMultipleSelection = allowMultipleSelection
  }

  func start() throws {
    NSLog("DEBUG [\(self.treeID)] Controller start() called")
    displayStore.con = self
    treeActions.con = self
    contextMenu.con = self

    self.app.registerTreePanelController(self.treeID, self)

    self.subscribeToSignals(treeID)

    self.swiftFilterState.onChangeCallback = self.onFilterChanged
  }

  func shutdown() throws {
    NSLog("DEBUG [\(self.treeID)] Controller shutdown() called")
    self.dispatchListener.unsubscribeAll()

    self.dispatcher.sendSignal(signal: .DEREGISTER_DISPLAY_TREE, senderID: self.treeID)
  }

  func reattachListeners(_ newTreeID: TreeID) {
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
  }

  public func updateDisplayTree(to newTree: DisplayTree) throws {
    NSLog("DEBUG [\(self.treeID)] Got new display tree (rootPath=\(newTree.rootPath), state=\(newTree.state))")
    self.app.execSync {
      if newTree.treeID != self.tree.treeID {
        NSLog("INFO  [\(self.treeID)] Changing treeID to \(newTree.treeID)")
        self.treeView = nil
        self.app.deregisterTreePanelController(self.tree.treeID)
        self.app.registerTreePanelController(newTree.treeID, self)
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
    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        NSLog("INFO [\(self.treeID)] Requesting start subtree load")
        // this calls to the backend to do the load, which will eventually (with luck) come back to call onLoadSubtreeDone()
        self.enableNodeUpdateSignals = false
        try self.backend.startSubtreeLoad(treeID: self.treeID)
      } catch {
        NSLog("ERROR [\(self.treeID)] Failed to load tree: \(error)")
        let errorMsg: String = "\(error)" // ew, heh
        self.reportError("Failed to load tree", errorMsg)
      }
    }
  }

  // Should be called by TreeViewController
  func connectTreeView(_ treeView: TreeViewController) {
    NSLog("INFO  [\(self.treeID)] Connecting TreeView to TreePanelController")
    self.treeView = treeView

    if self.readyToPopulate {
      DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
        self.populateTreeView()
      }
    } else {
      NSLog("DEBUG [\(self.treeID)] readyToPopulate is false")
    }
  }

  // MUST RUN INSIDE MAIN DQ
  private func clearModelAndTreeView() {
    // Clear display store & TreeView (which draws from display store)
    NSLog("DEBUG [\(treeID)] Clearing TreeView")
    self.displayStore.putRootChildList(self.tree.rootSN, [])
    self.treeView!.outlineView.reloadData()
  }

  func clearTreeAndDisplayLoadingMsg() {
    DispatchQueue.main.async {
      self.clearModelAndTreeView()
      self.appendEphemeralNode(nil, "Loading...")
    }
  }

  /**
   Executes async in a DispatchQueue, to ensure serial execution. This will catch and report exceptions.
   */
  private func populateTreeView() {
    DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
      do {
        try self.populateTreeView_NoLock()
      } catch {
        self.reportException("Failed to populate tree", error)
      }
    }
  }

  private func populateTreeView_NoLock() throws {
    NSLog("DEBUG [\(treeID)] Starting populateTreeView()")
    guard self.treeView != nil else {
      NSLog("DEBUG [\(treeID)] populateTreeView(): TreeView is nil. Setting readyToPopulate to true")
      readyToPopulate = true
      return
    }
    readyToPopulate = false

    let populateStartTimeMS = DispatchTime.now()

    NSLog("DEBUG populateTreeView_NoLock(): clearing tree and displaying loading msg")
    clearTreeAndDisplayLoadingMsg()

    let rows: RowsOfInterest
    do {
      rows = try self.app.backend.getRowsOfInterest(treeID: self.treeID)
      NSLog("DEBUG [\(treeID)] Got expanded=\(rows.expanded), selected=\(rows.selected)")
    } catch {
      reportException("Failed to fetch expanded node list", error)
      rows = RowsOfInterest() // non-fatal error
    }

    var queue = LinkedList<SPIDNodePair>()

    do {
      let topLevelSNList: [SPIDNodePair] = try self.tree.getChildListForRoot()
      NSLog("DEBUG [\(self.treeID)] populateTreeView(): Got \(topLevelSNList.count) top-level nodes for root (\(self.tree.rootSPID.guid))")

      DispatchQueue.main.async {
        self.displayStore.putRootChildList(self.tree.rootSN, topLevelSNList)
        if topLevelSNList.count == 0 {
          // clear loading node
          self.treeView!.outlineView.reloadData()
        }
      }
      queue.append(contentsOf: topLevelSNList)
    } catch OutletError.maxResultsExceeded(let actualCount) {
      // When both calls below have separate DispatchQueue WorkItems, sometimes nothing shows up.
      // Is it possible the WorkItems can arrive out of order? Need to research this.
      DispatchQueue.main.async {
        self.clearModelAndTreeView()
        self.appendEphemeralNode(nil, "ERROR: too many items to display (\(actualCount))")
      }
      return
    }

    var toExpandInOrder: [GUID] = []
    // populate each expanded dir:
    while !queue.isEmpty {

      let sn = queue.popFirst()!
      if sn.node.isDir && rows.expanded.contains(sn.spid.guid) {
        // only expand rows which are actually present:
        NSLog("DEBUG [\(treeID)] populateTreeView(): Will expand row: \(sn.spid.guid)")
        toExpandInOrder.append(sn.spid.guid)
        do {
          let childSNList: [SPIDNodePair] = try self.tree.getChildList(sn.spid)
          NSLog("DEBUG [\(treeID)] populateTreeView(): Got \(childSNList.count) child nodes for parent \(sn.spid)")

          DispatchQueue.main.async {
            self.displayStore.putChildList(sn, childSNList)
          }
          queue.append(contentsOf: childSNList)

        } catch OutletError.maxResultsExceeded(let actualCount) {
          // append err node and continue
          DispatchQueue.main.async {
            self.appendEphemeralNode(sn, "ERROR: too many items to display (\(actualCount))")
          }
        }
      }
    }

    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.treeID)] populateTreeView(): reloading entire tree")
      self.treeView!.outlineView.reloadItem(nil, reloadChildren: true)

      NSLog("DEBUG [\(self.treeID)] populateTreeView(): Expanding rows: \(toExpandInOrder)")
      self.restoreRowExpansionState(toExpandInOrder)

      self.restoreRowSelectionState(rows.selected)

      let timeElapsed = populateStartTimeMS.distance(to: DispatchTime.now())
      NSLog("INFO  [\(self.treeID)] populateTreeView() completed in \(timeElapsed.toString())")
      self.dispatcher.sendSignal(signal: .POPULATE_UI_TREE_DONE, senderID: self.treeID)
    }
  }

  func appendEphemeralNode(_ parentSN: SPIDNodePair?, _ nodeName: String) {
    let parentSPID = (parentSN == nil ? self.tree.rootSPID : parentSN!.spid)

    let ephemeralNode = EphemeralNode(nodeName, parent: parentSPID)
    let ephemeralSN = ephemeralNode.toSN()

    self.displayStore.putChildList(parentSN, [ephemeralSN])  // yeah, make sure we put this inside the main DQ or weird race conditions result

    var itemToReload = parentSN?.spid.guid
    if itemToReload == nil || itemToReload == self.tree.rootSPID.guid {
      itemToReload  = nil
    }
    self.treeView!.outlineView.reloadItem(itemToReload, reloadChildren: true)
    NSLog("DEBUG [\(self.treeID)] Appended ephemeral node to parent \(itemToReload ?? TOPMOST_GUID): guid=\(ephemeralSN.spid.guid) name='\(nodeName)' ")
  }

  private func restoreRowSelectionState(_ selected: Set<GUID>) {
    guard selected.count > 0 else {
      return
    }

    var indexSet = IndexSet()
    for guid in selected {
      let index = self.treeView!.outlineView.row(forItem: guid)
      if index >= 0 {
        indexSet.insert(index)
      } else {
        NSLog("DEBUG [\(self.treeID)] restoreRowSelectionState(): could not select row because it was not found: \(guid)")
      }
    }

    NSLog("DEBUG [\(self.treeID)] restoreRowSelectionState(): selecting \(indexSet.count) rows")
    self.treeView!.outlineView.selectRowIndexes(indexSet, byExtendingSelection: false)
  }

  private func restoreRowExpansionState(_ toExpandInOrder: [GUID]) {
    self.treeView!.outlineView.beginUpdates()
    // disable listeners while we restore expansion state
    self.treeView!.expandContractListenersEnabled = false
    defer {
      self.treeView!.expandContractListenersEnabled = true
      self.treeView!.outlineView.endUpdates()
    }

    for guid in toExpandInOrder {
      NSLog("DEBUG [\(self.treeID)] Expanding item: \"\(guid)\"")
      self.treeView!.outlineView.expandItem(guid)
    }
  }
  
  private func updateStatusBarMsg(_ statusBarMsg: String) {
    NSLog("DEBUG [\(self.treeID)] Updating status bar msg with content: \"\(statusBarMsg)\"")
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
    self.treeView!.reloadItem(guid, reloadChildren: true)

    /*
     3. Ancestors: need to update all direct ancestors, but take into account all of the children of each.
     */
    NSLog("DEBUG [\(treeID)] setNodeCheckedState(): checking ancestors of \(guid)")
    var ancestorGUID: GUID = guid
    while true {
      ancestorGUID = self.displayStore.getParentGUID(ancestorGUID)!
      NSLog("DEBUG [\(treeID)] setNodeCheckedState(): next higher ancestor: \(ancestorGUID)")
      if ancestorGUID == TOPMOST_GUID {
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
      NSLog("DEBUG [\(treeID)] Ancestor: \(ancestorGUID) hasChecked=\(hasChecked) hasUnchecked=\(hasUnchecked) hasMixed=\(hasMixed) => isChecked=\(isChecked) isMixed=\(isMixed)")
      self.setCheckedStateForSingleNode(ancestorSN!, isChecked: isChecked, isMixed: isMixed)
    }
  }

  private func setCheckedStateForSingleNode(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    let guid = sn.spid.guid
    NSLog("DEBUG [\(treeID)] Updating checkbox state of: \(guid) (\(sn.spid)) => \(isChecked)/\(isMixed)")

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

    var checkedQueue = LinkedList<SPIDNodePair>()
    var mixedQueue = LinkedList<SPIDNodePair>()

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
    // See listener in OutletApp
    NSLog("ERROR [\(self.treeID)] Reporting local error: title='\(title)' error='\(errorMsg)'")
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

    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.treeID)] Got signal: \(Signal.TREE_LOAD_STATE_UPDATED) with state=\(treeLoadState), status_msg=\(statusBarMsg)")
      self.treeLoadState = treeLoadState
      self.updateStatusBarMsg(statusBarMsg)

      switch treeLoadState {
      case .LOAD_STARTED:
        self.enableNodeUpdateSignals = true

        if self.swiftTreeState.isManualLoadNeeded {
          DispatchQueue.main.async {
            self.swiftTreeState.isManualLoadNeeded = false
          }
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
    let dirStatsDictByGUID = try propDict.get("dir_stats_dict_by_guid") as! Dictionary<GUID, DirectoryStats>
    let dirStatsDictByUID = try propDict.get("dir_stats_dict_by_uid") as! Dictionary<UID, DirectoryStats>

    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.treeID)] Updating dir stats with status msg: \"\(statusBarMsg)\"")
      self.updateStatusBarMsg(statusBarMsg)

      self.displayStore.updateDirStats(dirStatsDictByGUID, dirStatsDictByUID)
      self.treeView!.outlineView.reloadData()
    }
  }

  private func onNodeUpserted(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring upsert signal: signals are disabled")
      return
    }

    let sn = try propDict.get("sn") as! SPIDNodePair
    let parentGUID = sn.spid.parentGUID!
    NSLog("INFO  [\(self.treeID)] Received upserted node: \(sn.spid) for parent: \(parentGUID)")

    let alreadyPresent: Bool = self.displayStore.upsertSN(parentGUID, sn)

    DispatchQueue.main.async {
      if alreadyPresent {
        NSLog("DEBUG [\(self.treeID)] Upserted node was already present; reloading: \(sn.spid.guid)")
        self.treeView!.reloadItem(sn.spid.guid, reloadChildren: true)
      } else {
        self.treeView!.reloadItem(parentGUID, reloadChildren: true)
      }
    }
  }

  private func onNodeRemoved(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring remove signal: signals are disabled")
      return
    }

    let sn = try propDict.get("sn") as! SPIDNodePair
    let parentGUID = sn.spid.parentGUID!
    NSLog("DEBUG [\(self.treeID)] Received removed node: \(sn.spid)")

    if self.displayStore.removeSN(sn.spid.guid) {
      DispatchQueue.main.async {
        self.treeView!.reloadItem(parentGUID, reloadChildren: true)
      }
    }
  }

  private func onSubtreeNodesChanged(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring SubtreeChanged signal: signals are disabled")
      return
    }
    let subtreeRootSPID = try propDict.get("subtree_root_spid") as! SPID
    let upsertedList = try propDict.get("upserted_sn_list") as! [SPIDNodePair]
    let removedList = try propDict.get("removed_sn_list") as! [SPIDNodePair]

    NSLog("DEBUG [\(self.treeID)] Received changes with root \(subtreeRootSPID) and \(upsertedList.count) upserts & \(removedList.count) removes")

    for upsertedSN in upsertedList {
      _ = self.displayStore.upsertSN(upsertedSN.spid.parentGUID!, upsertedSN)
    }
    for removedSN in removedList {
      _ = self.displayStore.removeSN(removedSN.spid.guid)
    }

    DispatchQueue.main.async {
      // just reload everything for now. Revisit if performance proves to be an issue
      self.treeView!.outlineView.reloadData()
    }
  }

  private func onGDriveDownloadDone(_ senderID: SenderID, _ propDict: PropDict) throws {
    let filename = try propDict.getString("filename")

    NSLog("DEBUG [\(treeID)] GDrive download complete: opening local file with default app: \(filename)")
    self.treeActions.openLocalFileWithDefaultApp(filename)
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
    DispatchQueue.global(qos: .userInteractive).async { [unowned self] in

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
