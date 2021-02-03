//
//  TreeController.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-01.
//  Copyright © 2021 Ibotta. All rights reserved.
//

/**
 PROTOCOL TreeControllable
 */
protocol TreeControllable {
  var app: OutletApp { get }
  var backend: OutletBackend { get }
  var dispatcher: SignalDispatcher { get }
  var tree: DisplayTree { get }
  var treeID: TreeID { get }
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

  init(_ treeID: String) {
    self.app = MockApp()
    // dummy data follows
    let spid = NodeIdentifierFactory.getRootConstantLocalDiskSPID()
    let rootSN = (NodeIdentifierFactory.getRootConstantLocalDiskSPID(), LocalDirNode(spid, NULL_UID, .NOT_TRASHED, isLive: false))
    self.tree = NullDisplayTree(backend: MockBackend(), state: DisplayTreeUiState(treeID: treeID, rootSN: rootSN, rootExists: false, offendingPath: nil, treeDisplayMode: .ONE_TREE_ALL_ITEMS, hasCheckboxes: false))
  }
}

/**
 CLASS TreeController
 */
class TreeController: TreeControllable {
  let app: OutletApp
  var tree: DisplayTree

  init(app: OutletApp, tree: DisplayTree) {
    self.app = app
    self.tree = tree
  }
}
