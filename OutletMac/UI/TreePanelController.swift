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

  func loadTree() throws

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

  init(_ treeID: String, canChangeRoot: Bool) {
    self.app = MockApp()
    self.canChangeRoot = canChangeRoot
    // dummy data follows
    let spid = LocalNodeIdentifier(NULL_UID, deviceUID: NULL_UID, ROOT_PATH)
    let rootSN = (spid, LocalDirNode(spid, NULL_UID, .NOT_TRASHED, isLive: false))
    self.tree = MockDisplayTree(backend: MockBackend(), state: DisplayTreeUiState(treeID: treeID, rootSN: rootSN, rootExists: false, offendingPath: nil, treeDisplayMode: .ONE_TREE_ALL_ITEMS, hasCheckboxes: false))
    self.swiftTreeState = SwiftTreeState.from(self.tree)
    let filterCriteria = FilterCriteria()
    self.swiftFilterState = SwiftFilterState.from(filterCriteria)

    self.dispatchListener = self.app.dispatcher.createListener(self.tree.treeID)

    self.swiftTreeState.statusBarMsg = "Status msg for \(self.treeID)"
  }

  func start() throws {
  }

  func shutdown() throws {
  }

  func loadTree() throws {
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
  let dispatchListener: DispatchListener
  lazy var displayStore: DisplayStore = DisplayStore(self)
  lazy var treeActions: TreeActions = TreeActions(self)
  lazy var contextMenu: TreeContextMenu = TreeContextMenu(self)

  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

  var treeView: TreeViewController? = nil
  // workaround for race condition, in case we are ready to populate before the UI is ready
  private var readyToPopulate: Bool = false

  var canChangeRoot: Bool
  var allowMultipleSelection: Bool

  private lazy var filterTimer = HoldOffTimer(FILTER_APPLY_DELAY_MS, self.fireFilterTimer)
  private lazy var statsRefreshTimer = HoldOffTimer(STATS_REFRESH_HOLDOFF_TIME_MS, self.fireRequestStatsRefresh)

  init(app: OutletApp, tree: DisplayTree, filterCriteria: FilterCriteria, canChangeRoot: Bool, allowMultipleSelection: Bool) {
    self.app = app
    self.tree = tree
    self.swiftTreeState = SwiftTreeState.from(tree)
    self.dispatchListener = self.app.dispatcher.createListener(tree.treeID)
    self.swiftFilterState = SwiftFilterState.from(filterCriteria)
    self.canChangeRoot = canChangeRoot
    self.allowMultipleSelection = allowMultipleSelection
  }

  func start() throws {
    self.app.registerTreePanelController(self.treeID, self)

    self.swiftFilterState.onChangeCallback = self.onFilterChanged
    try self.dispatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, self.onEnableUIToggled)
    try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_STARTED, self.onLoadStarted, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_DONE, self.onLoadSubtreeDone, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .DISPLAY_TREE_CHANGED, self.onDisplayTreeChanged, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .CANCEL_ALL_EDIT_ROOT, self.onEditingRootCancelled)
    try self.dispatchListener.subscribe(signal: .CANCEL_OTHER_EDIT_ROOT, self.onEditingRootCancelled, blacklistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .SET_STATUS, self.onSetStatus, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .REFRESH_SUBTREE_STATS_DONE, self.onRefreshStatsDone, whitelistSenderID: self.treeID)
  }

  func shutdown() throws {
    try self.dispatchListener.unsubscribeAll()

    self.dispatcher.sendSignal(signal: .DEREGISTER_DISPLAY_TREE, senderID: self.treeID)
  }

  func loadTree() throws {
    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        // this calls to the backend to do the load, which will eventually (with luck) come back to call onLoadSubtreeDone()
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
    self.treeView = treeView

    if self.readyToPopulate {
      DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
        do {
          try self.populateTreeView()
        } catch {
          self.reportException("Failed to populate tree", error)
        }
      }
    }
  }

  private func clearModelAndTreeView() {
    // Clear display store & treeview (which draws from display store)
    self.displayStore.repopulateRoot([])
    DispatchQueue.main.async {
      self.treeView!.outlineView.reloadData()
    }
  }

  private func populateTreeView() throws {
    guard self.treeView != nil else {
      NSLog("DEBUG populateTreeView(): TreeView is nil. Setting readyToPopulate = true")
      readyToPopulate = true
      return
    }
    readyToPopulate = false

    let rows: RowsOfInterest
    do {
      rows = try self.app.backend.getRowsOfInterest(treeID: self.treeID)
      NSLog("DEBUG [\(treeID)] Got expanded rows: \(rows.expanded) and selected rows: \(rows.selected)")
    } catch {
      reportException("Failed to fetch expanded node list", error)
      rows = RowsOfInterest() // non-fatal error
    }

    self.clearModelAndTreeView()
    // TODO: change this to timer which can be cancelled, so we only display if ~500ms have elapsed
    self.appendEphemeralNode(nil, "Loading...")

    var queue = LinkedList<SPIDNodePair>()

    do {
      let topLevelNodeList: [Node] = try self.tree.getChildListForRoot()
      NSLog("DEBUG [\(treeID)] populateTreeView(): Got \(topLevelNodeList.count) top-level nodes for root")

      let topLevelSNList: [SPIDNodePair] = try self.displayStore.convertChildList(self.tree.rootSN, topLevelNodeList)
      self.displayStore.repopulateRoot(topLevelSNList)
      queue.append(contentsOf: topLevelSNList)
    } catch OutletError.maxResultsExceeded(let actualCount) {
      // When both calls below have separate DispatchQueue workitems, sometimes nothing shows up.
      // Is it possible the workitems can arrive out of order? Need to research this.
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
      let node = sn.node!
      if node.isDir && rows.expanded.contains(node.uid) {
        toExpandInOrder.append(self.displayStore.guidFor(sn))
        do {
          let childNodeList: [Node] = try self.tree.getChildList(node)
          NSLog("DEBUG [\(treeID)] populateTreeView(): Got \(childNodeList.count) child nodes for parent \(node.uid)")

          let childSNList: [SPIDNodePair] = try self.displayStore.convertChildList(sn, childNodeList)
          self.displayStore.populateChildList(sn, childSNList)
          queue.append(contentsOf: childSNList)

        } catch OutletError.maxResultsExceeded(let actualCount) {
          // append err node and continue
          self.appendEphemeralNode(sn, "ERROR: too many items to display (\(actualCount))")
        }
      }
    }

    DispatchQueue.main.async {
      self.restoreExpandedRows(toExpandInOrder)

      // FIXME: UID->GUID doesn't map!





      if rows.selected.count > 0 {
        var indexSet = IndexSet()
        for uid in rows.selected {
          let index = self.treeView!.outlineView.row(forItem: uid)
          if index >= 0 {
            indexSet.insert(index)
          } else {
            NSLog("DEBUG [\(self.treeID)] populateTreeView(): could not select row because it was not found: \(uid)")
          }
        }

        NSLog("DEBUG [\(self.treeID)] populateTreeView(): selecting \(indexSet.count) rows")
        self.treeView!.outlineView.selectRowIndexes(indexSet, byExtendingSelection: false)
      }

      // remember to kick this off inside the main dispatch queue
      NSLog("DEBUG [\(self.treeID)] Rescheduling stats refresh timer")
      self.statsRefreshTimer.reschedule()

      self.dispatcher.sendSignal(signal: .POPULATE_UI_TREE_DONE, senderID: self.treeID)
    }
  }

  func appendEphemeralNode(_ parentSN: SPIDNodePair?, _ nodeName: String) {
    let parentGUID = self.displayStore.guidFor(parentSN)
    do {
      let ephemeralChildSN = try self.displayStore.convertSingleNode(parentSN, node: EmptyNode(nodeName))
      self.displayStore.populateChildList(parentSN, [ephemeralChildSN])
    } catch {
      NSLog("ERROR [\(self.treeID)] Failed to append ephemeral node: \(error)")
      return
    }
    DispatchQueue.main.async {
      self.treeView!.outlineView.reloadItem(parentGUID, reloadChildren: true)
      NSLog("DEBUG [\(self.treeID)] Appended ephemeral node: '\(nodeName)'")
    }
  }

  private func restoreExpandedRows(_ toExpandInOrder: [GUID]) {
    self.treeView!.outlineView.beginUpdates()
    defer {
      self.treeView!.outlineView.endUpdates()
    }

    self.treeView!.outlineView.reloadData()

    // disable listeners while we restore expansion state
    self.treeView!.expandContractListenersEnabled = false
    defer {
      self.treeView!.expandContractListenersEnabled = true
    }
    for guid in toExpandInOrder {
      self.treeView!.outlineView.expandItem(guid)
    }
  }
  
  private func updateStatusBarMsg(_ statusMsg: String) {
    NSLog("DEBUG [\(self.treeID)] Updating status bar msg with content: \"\(statusMsg)\"")
    DispatchQueue.main.async {
      self.swiftTreeState.statusBarMsg = statusMsg
    }
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

  private func onEnableUIToggled(_ senderID: SenderID, _ props: PropDict) throws {
    if !self.canChangeRoot {
      assert(!self.swiftTreeState.isUIEnabled)
      return
    }
    let isEnabled = try props.getBool("enable")
    DispatchQueue.main.async {
      self.swiftTreeState.isUIEnabled = isEnabled
    }
  }

  private func onLoadStarted(_ senderID: SenderID, _ props: PropDict) throws {
    if self.swiftTreeState.isManualLoadNeeded {
      DispatchQueue.main.async {
        self.swiftTreeState.isManualLoadNeeded = false
      }
    }
  }

  private func onLoadSubtreeDone(_ senderID: SenderID, _ props: PropDict) throws {
    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        try self.populateTreeView()
      } catch {
        NSLog("ERROR [\(self.treeID)] Failed to populate tree: \(error)")
        let errorMsg: String = "\(error)" // ew, heh
        self.reportError("Failed to populate tree", errorMsg)
      }
    }
  }

  private func onDisplayTreeChanged(_ senderID: SenderID, _ props: PropDict) throws {
    self.tree = try props.get("tree") as! DisplayTree
    NSLog("DEBUG [\(self.treeID)] Got new display tree (rootPath=\(self.tree.rootPath))")
    DispatchQueue.main.async {
      self.swiftTreeState.updateFrom(self.tree)
    }

    try self.loadTree()
  }

  private func onEditingRootCancelled(_ senderID: SenderID, _ props: PropDict) throws {
    NSLog("DEBUG [\(self.treeID)] Editing cancelled (was: \(self.swiftTreeState.isEditingRoot)); setting rootPath to \(self.tree.rootPath)")
    DispatchQueue.main.async {
      // restore root path to value received from server
      self.swiftTreeState.rootPath = self.tree.rootPath
      self.swiftTreeState.isEditingRoot = false
    }
  }

  private func onSetStatus(_ senderID: SenderID, _ props: PropDict) throws {
    let statusBarMsg = try props.getString("status_msg")
    self.updateStatusBarMsg(statusBarMsg)
  }

  private func onRefreshStatsDone(_ senderID: SenderID, _ props: PropDict) throws {
    let statusBarMsg = try props.getString("status_msg")
    self.updateStatusBarMsg(statusBarMsg)
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
        try self.backend.enqueueRefreshSubtreeStatsTask(rootUID: self.tree.rootSPID.uid, treeID: self.treeID)
      } catch {
        reportException("Request to refresh stats failed", error)
      }
    }
  }

}
