//
//  TreeController.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-01.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI
import LinkedList

/**
 PROTOCOL TreeControllable
 */
protocol TreeControllable: HasLifecycle {
  var app: OutletApp { get }
  var tree: DisplayTree { get }
  var swiftTreeState: SwiftTreeState { get }
  var swiftFilterState: SwiftFilterState { get }

  var treeView: TreeViewController? { get set }
  var displayStore: DisplayStore { get }

  // Convenience getters - see extension below
  var backend: OutletBackend { get }
  var dispatcher: SignalDispatcher { get }
  var treeID: TreeID { get }

  var dispatchListener: DispatchListener { get }

  func start() throws

  func connectTreeView(_ treeView: TreeViewController)

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
 CLASS MockTreeController

 Non-functioning implementation of TreeControllable. Should only be used for testing & previews
 */
class MockTreeController: TreeControllable {
  let app: OutletApp
  var tree: DisplayTree
  let dispatchListener: DispatchListener
  lazy var displayStore: DisplayStore = DisplayStore(self)

  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

  var treeView: TreeViewController? = nil

  init(_ treeID: String) {
    self.app = MockApp()
    // dummy data follows
    let spid = NodeIdentifierFactory.getRootConstantLocalDiskSPID()
    let rootSN = (NodeIdentifierFactory.getRootConstantLocalDiskSPID(), LocalDirNode(spid, NULL_UID, .NOT_TRASHED, isLive: false))
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

  func connectTreeView(_ treeView: TreeViewController) {
  }
  func reportError(_ title: String, _ errorMsg: String) {
  }

  func reportException(_ title: String, _ error: Error) {
  }

}

/**
 CLASS TreeController
 */
class TreeController: TreeControllable, ObservableObject {
  let app: OutletApp
  var tree: DisplayTree
  let dispatchListener: DispatchListener
  lazy var displayStore: DisplayStore = DisplayStore(self)

  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

  var treeView: TreeViewController? = nil
  // workaround for race condition, in case we are ready to populate before the UI is ready
  private var readyToPopulate: Bool = false

  var canChangeRoot: Bool = true // TODO

  init(app: OutletApp, tree: DisplayTree, filterCriteria: FilterCriteria) {
    self.app = app
    self.tree = tree
    self.swiftTreeState = SwiftTreeState.from(tree)
    self.dispatchListener = self.app.dispatcher.createListener(tree.treeID)
    self.swiftFilterState = SwiftFilterState.from(filterCriteria)
    self.swiftFilterState.onChangeCallback = self.onFilterChanged
  }

  func start() throws {
    try self.dispatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, self.onEnableUIToggled)
    try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_STARTED, self.onLoadStarted, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_DONE, self.onLoadSubtreeDone, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .DISPLAY_TREE_CHANGED, self.onDisplayTreeChanged, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .CANCEL_ALL_EDIT_ROOT, self.onEditingRootCancelled)
    try self.dispatchListener.subscribe(signal: .CANCEL_OTHER_EDIT_ROOT, self.onEditingRootCancelled, blacklistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .SET_STATUS, self.onSetStatus, whitelistSenderID: self.treeID)
  }

  func shutdown() throws {
    try self.dispatchListener.unsubscribeAll()
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

    // TODO: change this to timer which can be cancelled, so we only display if ~500ms have elapsed
    self.displayStore.repopulateRoot([])
    self.appendEphemeralNode(nil, "Loading...")

    var queue = LinkedList<Node>()

    let topLevelNodeList: [Node] = try self.tree.getChildListForRoot()
    NSLog("DEBUG [\(treeID)] populateTreeView(): Got \(topLevelNodeList.count) top-level nodes for root")

    if topLevelNodeList.count > MAX_NUMBER_DISPLAYABLE_CHILD_NODES {
      NSLog("ERROR [\(treeID)] populateTreeView(): Too many top-level nodes to display! (count=\(topLevelNodeList.count))")
      self.displayStore.repopulateRoot([])
      self.appendEphemeralNode(nil, "ERROR: too many items to display (\(topLevelNodeList.count))")
      return
    }

    self.displayStore.repopulateRoot(topLevelNodeList)
    queue.append(contentsOf: topLevelNodeList)

    var toExpandInOrder: [UID] = []
    // populate each expanded dir:
    while !queue.isEmpty {
      let node = queue.popFirst()!
      if node.isDir && rows.expanded.contains(node.uid) {
        toExpandInOrder.append(node.uid)
        let childList: [Node] = try self.tree.getChildList(node)
        NSLog("DEBUG [\(treeID)] populateTreeView(): Got \(childList.count) child nodes for parent \(node.uid)")

        if childList.count > MAX_NUMBER_DISPLAYABLE_CHILD_NODES {
          NSLog("ERROR [\(treeID)] populateTreeView(): Too many nodes under \(node.uid) to display! (count=\(childList.count))")
          self.appendEphemeralNode(node.uid, "ERROR: too many items to display (\(childList.count))")
        } else {
          // Acceptable number: populate all
          self.displayStore.populateChildList(node.uid, childList)
          queue.append(contentsOf: childList)
        }
      }
    }

    DispatchQueue.main.async {
      self.restoreExpandedRows(toExpandInOrder)

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


      // TODO: see if this junk is useful
//      let fittingSize = self.treeView!.outlineView.fittingSize
//      NSLog("FITTING SIZE IS NOW: \(fittingSize.width)x\(fittingSize.height)")
//      let preferredContentSize = CGSize(width: fittingSize.width, height: fittingSize.height)
    }

  }

  private func appendEphemeralNode(_ parent: UID?, _ nodeName: String) {
    // note: top-level's parent is 'nil' in OutlineView, but is NULL_UID in DisplayStore
    let parentUID: UID = parent == nil ? NULL_UID : parent!
    let node = EmptyNode(nodeName)
    self.displayStore.populateChildList(parentUID, [node])
    DispatchQueue.main.async {
      self.treeView!.outlineView.reloadItem(parent, reloadChildren: true)
    }
  }

  private func restoreExpandedRows(_ toExpandInOrder: [UID]) {
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
    for uid in toExpandInOrder {
      self.treeView!.outlineView.expandItem(uid)
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
    reportError("Failed to fetch expanded node list", errorMsg)
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

  func onLoadStarted(_ senderID: SenderID, _ props: PropDict) throws {
    if self.swiftTreeState.isManualLoadNeeded {
      DispatchQueue.main.async {
        self.swiftTreeState.isManualLoadNeeded = false
      }
    }
  }

  func onLoadSubtreeDone(_ senderID: SenderID, _ props: PropDict) throws {
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

  func onDisplayTreeChanged(_ senderID: SenderID, _ props: PropDict) throws {
    self.tree = try props.get("tree") as! DisplayTree
    NSLog("DEBUG [\(self.treeID)] Got new display tree (rootPath=\(self.tree.rootPath))")
    DispatchQueue.main.async {
      self.swiftTreeState.updateFrom(self.tree)
    }

    try self.loadTree()
  }

  func onEditingRootCancelled(_ senderID: SenderID, _ props: PropDict) throws {
    NSLog("DEBUG [\(self.treeID)] Editing cancelled (was: \(self.swiftTreeState.isEditingRoot)); setting rootPath to \(self.tree.rootPath)")
    DispatchQueue.main.async {
      // restore root path to value received from server
      self.swiftTreeState.rootPath = self.tree.rootPath
      self.swiftTreeState.isEditingRoot = false
    }
  }

  func onSetStatus(_ senderID: SenderID, _ props: PropDict) throws {
    let statusBarMsg = try props.getString("status_msg")
    NSLog("DEBUG [\(self.treeID)] Updating status bar msg with content: \"\(statusBarMsg)\"")
    DispatchQueue.main.async {
      self.swiftTreeState.statusBarMsg = statusBarMsg
    }
  }

  func onNodeExpansionToggled(_ senderID: SenderID, _ props: PropDict) throws {
    guard self.treeView != nil else {
      NSLog("ERROR onExpandRequested(): TreeView is nil!")
      return
    }

    // TODO
  }

  // Other callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func onFilterChanged(filterState: SwiftFilterState) {
    // TODO: set up a timer to only update the filter at most every X ms

    // ^^^ FIXME ^^^


    NSLog("DEBUG onFilterChanged(): \(filterState)")

    do {
      try self.app.backend.updateFilterCriteria(treeID: self.treeID, filterCriteria: filterState.toFilterCriteria())
    } catch {
      NSLog("ERROR Failed to update filter criteria on the backend: \(error)")
      return
    }
    do {
      try self.populateTreeView()
    } catch {
      reportException("Failed repopulate TreeView after filter change", error)
    }
  }
}
