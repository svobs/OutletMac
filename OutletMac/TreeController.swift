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
  var tree: DisplayTree { get }
  var swiftTreeState: SwiftTreeState { get }
  var swiftFilterState: SwiftFilterState { get }

  // Convenience getters - see extension below
  var backend: OutletBackend { get }
  var dispatcher: SignalDispatcher { get }
  var treeID: TreeID { get }

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
  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

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

}

/**
 CLASS SwiftTreeState

 Encapsulates *ONLY* the information required to redraw the SwiftUI views for a given DisplayTree.
 */
class SwiftTreeState: ObservableObject {
  @Published var isUIEnabled: Bool
  @Published var isRootExists: Bool
  @Published var isEditingRoot: Bool
  @Published var isManualLoadNeeded: Bool
  @Published var offendingPath: String?
  @Published var rootPath: String = ""
  @Published var statusBarMsg: String = ""

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

  static func from(_ tree: DisplayTree) -> SwiftTreeState {
    return SwiftTreeState(isUIEnabled: true, isRootExists: tree.rootExists, isEditingRoot: false, isManualLoadNeeded: tree.needsManualLoad,
                          offendingPath: tree.state.offendingPath, rootPath: tree.rootPath)
  }
}

/**
 CLASS SwiftFilterState

 See FilterCriteria class.
 Note that this class uses "isMatchCase", which is the inverse of FilterCriteria's "isIgnoreCase"
 */
class SwiftFilterState: ObservableObject {
  var onChangeCallback: FilterStateCallback? = nil

  @Published var searchQuery: String {
    didSet {
      NSLog("Search query changed: \(searchQuery)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var isMatchCase: Bool {
    didSet {
      NSLog("isMatchCase changed: \(isMatchCase)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }

  @Published var isTrashed: Ternary {
    didSet {
      NSLog("isTrashed changed: \(isTrashed)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var isShared: Ternary {
    didSet {
      NSLog("isShared changed: \(isShared)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var showAncestors: Bool {
    didSet {
      NSLog("showAncestors changed: \(showAncestors)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }

  init(onChangeCallback: FilterStateCallback? = nil, searchQuery: String, isMatchCase: Bool, isTrashed: Ternary, isShared: Ternary, showAncestors: Bool) {
    self.onChangeCallback = onChangeCallback
    self.searchQuery = searchQuery
    self.isMatchCase = isMatchCase
    self.isTrashed = isTrashed
    self.isShared = isShared
    self.showAncestors = showAncestors
  }

  func updateFrom(_ filter: FilterCriteria, onChangeCallback: FilterStateCallback? = nil) {
    self.onChangeCallback = onChangeCallback
    self.searchQuery = filter.searchQuery
    self.isMatchCase = !filter.isIgnoreCase
    self.isTrashed = filter.isTrashed
    self.isShared = filter.isShared
    self.showAncestors = filter.showSubtreesOfMatches
  }

  func toFilterCriteria() -> FilterCriteria {
    return FilterCriteria(searchQuery: searchQuery, isTrashed: isTrashed, isShared: isShared, isIgnoreCase: !isMatchCase, showSubtreesOfMatches: showAncestors)
  }

  static func from(_ filter: FilterCriteria, onChangeCallback: FilterStateCallback? = nil) -> SwiftFilterState {
    return SwiftFilterState(onChangeCallback: onChangeCallback, searchQuery: filter.searchQuery, isMatchCase: !filter.isIgnoreCase, isTrashed: filter.isTrashed, isShared: filter.isShared, showAncestors: filter.showSubtreesOfMatches)
  }
}

typealias FilterStateCallback = (SwiftFilterState) -> Void

/**
 CLASS TreeController
 */
class TreeController: TreeControllable, ObservableObject {
  let app: OutletApp
  var tree: DisplayTree
  let dispatchListener: DispatchListener

  var swiftTreeState: SwiftTreeState
  var swiftFilterState: SwiftFilterState

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
    try self.dispatchListener.subscribe(signal: .DISPLAY_TREE_CHANGED, self.onDisplayTreeChanged, whitelistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .CANCEL_ALL_EDIT_ROOT, self.onEditingRootCancelled)
    try self.dispatchListener.subscribe(signal: .CANCEL_OTHER_EDIT_ROOT, self.onEditingRootCancelled, blacklistSenderID: self.treeID)
    try self.dispatchListener.subscribe(signal: .SET_STATUS, self.onSetStatus, whitelistSenderID: self.treeID)
  }

  func onFilterChanged(filterState: SwiftFilterState) {
    // TODO: set up a timer to only update the filter at most every X ms

    do {
      try self.app.backend?.updateFilterCriteria(treeID: self.treeID, filterCriteria: filterState.toFilterCriteria())
    } catch {
      NSLog("Failed to update filter criteria on the backend: \(error)")
    }
  }

  // Dispatch Listeners
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

  func onDisplayTreeChanged(_ senderID: SenderID, _ props: PropDict) throws {
    self.tree = try props.get("tree") as! DisplayTree
    NSLog("[\(self.treeID)] Got new display tree (rootPath=\(self.tree.rootPath))")
    DispatchQueue.main.async {
      self.swiftTreeState.updateFrom(self.tree)
    }
  }

  func onEditingRootCancelled(_ senderID: SenderID, _ props: PropDict) throws {
    NSLog("[\(self.treeID)] Editing cancelled (was: \(self.swiftTreeState.isEditingRoot)); setting rootPath to \(self.tree.rootPath)")
    DispatchQueue.main.async {
      // restore root path to value received from server
      self.swiftTreeState.rootPath = self.tree.rootPath
      self.swiftTreeState.isEditingRoot = false
    }
  }

  func onSetStatus(_ senderID: SenderID, _ props: PropDict) throws {
    let statusBarMsg = try props.getString("status_msg")
    NSLog("Updating status bar msg with content: \"\(statusBarMsg)\"")
    DispatchQueue.main.async {
      self.swiftTreeState.statusBarMsg = statusBarMsg
    }
  }
}
