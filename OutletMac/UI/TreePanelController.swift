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

  var canChangeRoot: Bool { get }
  var allowMultipleSelection: Bool { get }

  var dispatchListener: DispatchListener { get }

  func updateDisplayTree(to newTree: DisplayTree) throws
  func requestTreeLoad() throws
  func generateCheckedRowList() throws -> [SPIDNodePair]
  func setChecked(_ guid: GUID, _ isChecked: Bool) throws

  func connectTreeView(_ treeView: TreeViewController)
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
 CLASS MockTreePanelController

 Non-functioning implementation of TreePanelControllable. Should only be used for testing & previews
 */
class MockTreePanelController: TreePanelControllable {
  let app: OutletApp
  var tree: DisplayTree
  let dispatchListener: DispatchListener
  lazy var displayStore: DisplayStore = DisplayStore(self)

  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

  var treeView: TreeViewController? = nil
  lazy var treeActions: TreeActions = TreeActions(self)
  lazy var contextMenu: TreeContextMenu = TreeContextMenu(self)

  var canChangeRoot: Bool

  var allowMultipleSelection: Bool {
    get {
      return true
    }
  }

  init(_ treeID: String, canChangeRoot: Bool) throws {
    self.app = MockApp()
    self.canChangeRoot = canChangeRoot
    // dummy data follows
    let spid = LocalNodeIdentifier(NULL_UID, deviceUID: NULL_UID, ROOT_PATH)
    let rootSN = (spid, LocalDirNode(spid, NULL_UID, .NOT_TRASHED, isLive: false))
    self.tree = MockDisplayTree(backend: MockBackend(), state: DisplayTreeUiState(treeID: treeID, rootSN: rootSN, rootExists: false, offendingPath: nil, needsManualLoad: false, treeDisplayMode: .ONE_TREE_ALL_ITEMS, hasCheckboxes: false))
    self.swiftTreeState = try SwiftTreeState.from(self.tree)
    let filterCriteria = FilterCriteria()
    self.swiftFilterState = SwiftFilterState.from(filterCriteria)

    self.dispatchListener = self.app.dispatcher.createListener(self.tree.treeID)

    self.swiftTreeState.statusBarMsg = "Status msg for \(self.treeID)"
  }

  func start() throws {
  }

  func shutdown() throws {
  }

  func updateDisplayTree(to newTree: DisplayTree) throws {
  }

  func setChecked(_ guid: GUID, _ isChecked: Bool) throws {
  }

  func generateCheckedRowList() throws -> [SPIDNodePair] {
    return []
  }

  func requestTreeLoad() throws {
  }

  func connectTreeView(_ treeView: TreeViewController) {
  }

  func reportError(_ title: String, _ errorMsg: String) {
  }

  func reportException(_ title: String, _ error: Error) {
  }

  func appendEphemeralNode(_ parentSN: SPIDNodePair?, _ nodeName: String) {
  }
}

/**
 CLASS TreePanelController

 Serves as the controller for the entire tree panel for a single UI tree.

 Equivalent to "TreeController" in the Python/GTK3 version of the app, but renamed in the Mac version so as not
 to be confused with the TreeViewController (which is an AppKit controller for NSOutlineView)
 */
class TreePanelController: TreePanelControllable {
  let app: OutletApp
  var tree: DisplayTree
  var dispatchListener: DispatchListener
  lazy var displayStore: DisplayStore = DisplayStore(self)
  lazy var treeActions: TreeActions = TreeActions(self)
  lazy var contextMenu: TreeContextMenu = TreeContextMenu(self)

  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

  var treeView: TreeViewController? = nil
  // workaround for race condition, in case we are ready to populate before the UI is ready
  private var readyToPopulate: Bool = false

  var enableNodeUpdateSignals: Bool = false

  var canChangeRoot: Bool
  var allowMultipleSelection: Bool

  private lazy var filterTimer = HoldOffTimer(FILTER_APPLY_DELAY_MS, self.fireFilterTimer)
  private lazy var statsRefreshTimer = HoldOffTimer(STATS_REFRESH_HOLDOFF_TIME_MS, self.fireRequestStatsRefresh)

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
    self.dispatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, self.onEnableUIToggled)
    self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_STARTED, self.onLoadStarted, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_DONE, self.onLoadSubtreeDone, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .DISPLAY_TREE_CHANGED, self.onDisplayTreeChanged, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .CANCEL_ALL_EDIT_ROOT, self.onEditingRootCancelled)
    self.dispatchListener.subscribe(signal: .CANCEL_OTHER_EDIT_ROOT, self.onEditingRootCancelled, blacklistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .SET_STATUS, self.onSetStatus, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .REFRESH_SUBTREE_STATS_DONE, self.onRefreshStatsDone, whitelistSenderID: treeID)

    self.dispatchListener.subscribe(signal: .NODE_UPSERTED, self.onNodeUpserted, whitelistSenderID: treeID)
    self.dispatchListener.subscribe(signal: .NODE_REMOVED, self.onNodeRemoved, whitelistSenderID: treeID)
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
        do {
          try self.populateTreeView()
        } catch {
          self.reportException("Failed to populate tree", error)
        }
      }
    } else {
      NSLog("DEBUG [\(self.treeID)] readyToPopulate is false")
    }
  }

  private func clearModelAndTreeView() {
    // Clear display store & TreeView (which draws from display store)
    self.displayStore.putRootChildList(self.tree.rootSN, [])
    DispatchQueue.main.async {
      self.treeView!.outlineView.reloadData()
    }
  }

  private func populateTreeView() throws {
    NSLog("DEBUG [\(treeID)] Starting populateTreeView()")
    guard self.treeView != nil else {
      NSLog("DEBUG [\(treeID)] populateTreeView(): TreeView is nil. Setting readyToPopulate = true")
      readyToPopulate = true
      return
    }
    readyToPopulate = false

    self.clearModelAndTreeView()
    // TODO: change this to timer which can be cancelled, so we only display if ~500ms have elapsed
    self.appendEphemeralNode(nil, "Loading...")

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
      NSLog("DEBUG [\(treeID)] populateTreeView(): Got \(topLevelSNList.count) top-level nodes for root")

      self.displayStore.putRootChildList(self.tree.rootSN, topLevelSNList)
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

          self.displayStore.putChildList(sn, childSNList)
          queue.append(contentsOf: childSNList)

        } catch OutletError.maxResultsExceeded(let actualCount) {
          // append err node and continue
          self.appendEphemeralNode(sn, "ERROR: too many items to display (\(actualCount))")
        }
      }
    }

    DispatchQueue.main.async {
      // Reload entire tree:
      self.treeView!.outlineView.reloadItem(nil, reloadChildren: true)

      NSLog("DEBUG [\(self.treeID)] populateTreeView(): Expanding rows: \(toExpandInOrder)")
      self.restoreRowExpansionState(toExpandInOrder)

      self.restoreRowSelectionState(rows.selected)

      // remember to kick this off inside the main dispatch queue
      NSLog("DEBUG [\(self.treeID)] Rescheduling stats refresh timer")
      self.statsRefreshTimer.reschedule()

      self.dispatcher.sendSignal(signal: .POPULATE_UI_TREE_DONE, senderID: self.treeID)
    }
  }

  func appendEphemeralNode(_ parentSN: SPIDNodePair?, _ nodeName: String) {
    let parentGUID = parentSN?.spid.guid
    let ephemeralNode = EphemeralNode(nodeName, parent: parentSN?.spid ?? nil)
    let ephemeralSN = (ephemeralNode.nodeIdentifier as! SPID, ephemeralNode)
    self.displayStore.putChildList(parentSN, [ephemeralSN])

    DispatchQueue.main.async {
      self.treeView!.outlineView.reloadItem(parentGUID, reloadChildren: true)
      NSLog("DEBUG [\(self.treeID)] Appended ephemeral node: '\(nodeName)'")
    }
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
    defer {
      self.treeView!.outlineView.endUpdates()
    }

    // disable listeners while we restore expansion state
    self.treeView!.expandContractListenersEnabled = false
    defer {
      self.treeView!.expandContractListenersEnabled = true
    }
    for guid in toExpandInOrder {
      NSLog("DEBUG [\(self.treeID)] Expanding item: \"\(guid)\"")
      self.treeView!.outlineView.expandItem(guid)
    }
  }
  
  private func updateStatusBarMsg(_ statusMsg: String) {
    NSLog("DEBUG [\(self.treeID)] Updating status bar msg with content: \"\(statusMsg)\"")
    DispatchQueue.main.async {
      self.swiftTreeState.statusBarMsg = statusMsg
    }
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
      for childSN in self.displayStore.getChildList(ancestorGUID) {
        if self.displayStore.isCheckboxChecked(childSN) {
          hasChecked = true
        } else {
          hasUnchecked = true
        }
        hasMixed = hasMixed || self.displayStore.isCheckboxMixed(childSN)
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
    self.displayStore.updateCheckedStateTracking(sn, isChecked: isChecked, isMixed: isMixed)

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
    self.dispatcher.sendSignal(signal: .ERROR_OCCURRED, senderID: treeID, ["msg": title, "secondary_msg": errorMsg])
  }

  func reportException(_ title: String, _ error: Error) {
    let errorMsg: String = "\(error)" // ew, heh
    NSLog("ERROR [\(self.treeID)] title='\(title)' error'\(errorMsg)'")
    reportError(title, errorMsg)
  }


  // DispatchListener callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func onEnableUIToggled(_ senderID: SenderID, _ propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("enable")
    DispatchQueue.main.async {
      self.swiftTreeState.isUIEnabled = isEnabled
    }
  }

  private func onLoadStarted(_ senderID: SenderID, _ propDict: PropDict) throws {
    if self.swiftTreeState.isManualLoadNeeded {
      DispatchQueue.main.async {
        self.swiftTreeState.isManualLoadNeeded = false
      }
    }
  }

  private func onLoadSubtreeDone(_ senderID: SenderID, _ propDict: PropDict) throws {
    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        self.enableNodeUpdateSignals = true
        try self.populateTreeView()
      } catch {
        NSLog("ERROR [\(self.treeID)] Failed to populate tree: \(error)")
        let errorMsg: String = "\(error)" // ew, heh
        self.reportError("Failed to populate tree", errorMsg)
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

  private func onSetStatus(_ senderID: SenderID, _ propDict: PropDict) throws {
    let statusBarMsg = try propDict.getString("status_msg")
    self.updateStatusBarMsg(statusBarMsg)
  }

  private func onRefreshStatsDone(_ senderID: SenderID, _ propDict: PropDict) throws {
    let statusBarMsg = try propDict.getString("status_msg")
    self.updateStatusBarMsg(statusBarMsg)
  }

  private func onNodeUpserted(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring upsert signal: signals are disabled")
      return
    }

    let sn = try propDict.get("sn") as! SPIDNodePair
    let parentGUID = try propDict.get("parent_guid") as! String
    NSLog("DEBUG [\(self.treeID)] Received upserted node: \(sn.spid) to parent: \(parentGUID)")

    let alreadyPresent: Bool = self.displayStore.upsertSN(parentGUID, sn)

    if alreadyPresent {
      NSLog("DEBUG [\(self.treeID)] Upserted node was already present; reloading: \(sn.spid.guid)")
      self.treeView!.reloadItem(sn.spid.guid, reloadChildren: true)
    } else {
      self.treeView!.reloadItem(parentGUID, reloadChildren: true)
    }
  }

  private func onNodeRemoved(_ senderID: SenderID, _ propDict: PropDict) throws {
    if !self.enableNodeUpdateSignals {
      NSLog("DEBUG [\(self.treeID)] Ignoring remove signal: signals are disabled")
      return
    }

    let sn = try propDict.get("sn") as! SPIDNodePair
    let parentGUID = try propDict.get("parent_guid") as! String
    NSLog("DEBUG [\(self.treeID)] Received removed node: \(sn.spid)")

    if self.displayStore.removeSN(sn.spid.guid) {
      self.treeView!.removeItem(sn.spid.guid, parentGUID: parentGUID)
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
    NSLog("DEBUG [\(self.treeID)] Firing timer to update filter via BE")

    do {
      try self.app.backend.updateFilterCriteria(treeID: self.treeID, filterCriteria: self.swiftFilterState.toFilterCriteria())
    } catch {
      NSLog("ERROR [\(self.treeID)] Failed to update filter criteria on the backend: \(error)")
      return
    }
    do {
      try self.populateTreeView()
    } catch {
      reportException("Failed to repopulate TreeView after filter change", error)
    }
  }

  private func fireRequestStatsRefresh() {
    NSLog("DEBUG [\(self.treeID)] Requesting subtree stats refresh")

    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        try self.backend.enqueueRefreshSubtreeStatsTask(rootUID: self.tree.rootSPID.nodeUID, treeID: self.treeID)
      } catch {
        reportException("Request to refresh stats failed", error)
      }
    }
  }

}
