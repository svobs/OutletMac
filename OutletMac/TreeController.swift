//
//  TreeController.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-01.
//  Copyright © 2021 Ibotta. All rights reserved.
//
protocol TreeControllable {
  var app: OutletApp { get }
  var backend: OutletBackend { get }
  var tree: DisplayTree { get }
}

/**
 CLASS MockTreeController

 Non-functioning implementation of TreeControllable. Should only be used for testing & previews
 */
class MockTreeController: TreeControllable {
  let app: OutletApp
  var backend: OutletBackend {
    get {
      return app.backend!
    }
  }
  let spid: SinglePathNodeIdentifier
  let rootSN: SPIDNodePair
  var tree: DisplayTree

  init(_ treeID: String) {
    self.app = MockApp()
    // dummy data follows
    spid = NodeIdentifierFactory.getRootConstantLocalDiskSPID()
    rootSN = (NodeIdentifierFactory.getRootConstantLocalDiskSPID(), LocalDirNode(spid, NULL_UID, .NOT_TRASHED, isLive: false))
    tree = NullDisplayTree(backend: MockBackend(), state: DisplayTreeUiState(treeID: treeID, rootSN: rootSN, rootExists: false, offendingPath: nil, treeDisplayMode: .ONE_TREE_ALL_ITEMS, hasCheckboxes: false))
  }
}

class TreeController: TreeControllable {
  let app: OutletApp
  var backend: OutletBackend {
    get {
      return app.backend!
    }
  }
  var tree: DisplayTree

  init(app: OutletApp, tree: DisplayTree) {
    self.app = app
    self.tree = tree
  }
}
