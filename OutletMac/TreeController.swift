//
//  TreeController.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-01.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI

/**
 PROTOCOL TreeControllable
 */
protocol TreeControllable {
  var app: OutletApp { get }
  var backend: OutletBackend { get }
  var dispatcher: SignalDispatcher { get }
  var tree: DisplayTree { get }
  var treeID: TreeID { get }

  var uiState: TreeSwiftState { get }

  var dispatchListener: DispatchListener { get }

  func start() throws
}

/**
 Add convenience methods for commonly used sub-member objects
 */
extension TreeControllable {
  var backend: OutletBackend {
    get {
      return app.backend!
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
  var uiState: TreeSwiftState

  init(_ treeID: String) {
    self.app = MockApp()
    // dummy data follows
    let spid = NodeIdentifierFactory.getRootConstantLocalDiskSPID()
    let rootSN = (NodeIdentifierFactory.getRootConstantLocalDiskSPID(), LocalDirNode(spid, NULL_UID, .NOT_TRASHED, isLive: false))
    self.tree = NullDisplayTree(backend: MockBackend(), state: DisplayTreeUiState(treeID: treeID, rootSN: rootSN, rootExists: false, offendingPath: nil, treeDisplayMode: .ONE_TREE_ALL_ITEMS, hasCheckboxes: false))
    self.uiState = TreeSwiftState.from(self.tree)

    self.dispatchListener = self.app.dispatcher.createListener(self.tree.treeID)
  }

  func start() throws {
  }

}

/**
 Encapsulates *ONLY* the information required to redraw the SwiftUI views for a given DisplayTree.
 */
class TreeSwiftState: ObservableObject {
  @Published var isUIEnabled: Bool
  @Published var isRootExists: Bool
  @Published var isEditingRoot: Bool
  @Published var isManualLoadNeeded: Bool
  @Published var offendingPath: String?
  @Published var rootPath: String = ""

  init(isUIEnabled: Bool, isRootExists: Bool, isEditingRoot: Bool, isManualLoadNeeded: Bool, offendingPath: String?, rootPath: String) {
    self.isUIEnabled = isUIEnabled
    self.isRootExists = isRootExists
    self.isEditingRoot = isEditingRoot
    self.isManualLoadNeeded = isManualLoadNeeded
    self.offendingPath = offendingPath
    self.rootPath = rootPath
  }

  func updateFrom(_ newTree: DisplayTree) {
    self.rootPath = newTree.rootPath
    self.offendingPath = newTree.state.offendingPath
    self.isRootExists = newTree.rootExists
    self.isEditingRoot = false
    self.isManualLoadNeeded = newTree.needsManualLoad
  }

  static func from(_ tree: DisplayTree) -> TreeSwiftState {
    return TreeSwiftState(isUIEnabled: true, isRootExists: tree.rootExists, isEditingRoot: false, isManualLoadNeeded: tree.needsManualLoad,
                          offendingPath: tree.state.offendingPath, rootPath: tree.rootPath)
  }
}

/**
 CLASS TreeController
 */
class TreeController: TreeControllable, ObservableObject {
  let app: OutletApp
  var tree: DisplayTree
  let dispatchListener: DispatchListener

  var uiState: TreeSwiftState

  var canChangeRoot: Bool = true // TODO

  init(app: OutletApp, tree: DisplayTree) {
    self.app = app
    self.tree = tree
    self.uiState = TreeSwiftState.from(tree)
    self.dispatchListener = self.app.dispatcher.createListener(tree.treeID)
  }

  func start() throws {
    try self.dispatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, self.onEnableUIToggled)
    try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_STARTED, self.onLoadStarted, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .DISPLAY_TREE_CHANGED, self.onDisplayTreeChanged, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .CANCEL_ALL_EDIT_ROOT, self.onEditingRootCancelled)
    try self.dispatchListener.subscribe(signal: .CANCEL_OTHER_EDIT_ROOT, self.onEditingRootCancelled, blacklistSenderID: self.treeID)
  }

  // Dispatch Listeners
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼
  func onEnableUIToggled(_ props: PropDict) throws {
    if !self.canChangeRoot {
      assert(!self.uiState.isUIEnabled)
      return
    }
    let isEnabled = try props.getBool("enable")
    DispatchQueue.main.async {
      self.uiState.isUIEnabled = isEnabled
    }
  }

  func onLoadStarted(_ params: PropDict) throws {
    if self.uiState.isManualLoadNeeded {
      DispatchQueue.main.async {
        self.uiState.isManualLoadNeeded = false
      }
    }
  }

  func onDisplayTreeChanged(_ params: PropDict) throws {
    self.tree = try params.get("tree") as! DisplayTree
    NSLog("[\(self.treeID)] Got new display tree (rootPath=\(self.tree.rootPath))")
    DispatchQueue.main.async {
      self.uiState.updateFrom(self.tree)
    }
  }

  func onEditingRootCancelled(_ params: PropDict) throws {
    NSLog("[\(self.treeID)] Editing cancelled (was: \(self.uiState.isEditingRoot)); setting rootPath to \(self.tree.rootPath)")
    DispatchQueue.main.async {
      // restore root path to value received from server
      self.uiState.rootPath = self.tree.rootPath
      self.uiState.isEditingRoot = false
    }
  }

}
