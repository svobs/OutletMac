//
//  TreeController.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-01.
//  Copyright © 2021 Ibotta. All rights reserved.
//
protocol TreeControllable {
  var backend: OutletBackend { get }
  var tree: DisplayTree { get }
}

/**
 CLASS NullTreeController

 Non-functioning implementation of TreeControllable. Should only be used for testing & previews
 */
class NullTreeController: TreeControllable {
  let backend: OutletBackend
  let spid: SinglePathNodeIdentifier
  let rootSN: SPIDNodePair
  var tree: DisplayTree

  init(_ treeID: String) {
    backend = NullBackend()
    // dummy data follows
    spid = NodeIdentifierFactory.getRootConstantLocalDiskSPID()
    rootSN = (NodeIdentifierFactory.getRootConstantLocalDiskSPID(), LocalDirNode(spid, NULL_UID, .NOT_TRASHED, isLive: false))
    tree = NullDisplayTree(backend: NullBackend(), state: DisplayTreeUiState(treeID: treeID, rootSN: rootSN, rootExists: false, offendingPath: nil, treeDisplayMode: .ONE_TREE_ALL_ITEMS, hasCheckboxes: false))
  }
}

class TreeController: TreeControllable {
  var backend: OutletBackend
  var tree: DisplayTree

  init(backend: OutletBackend, tree: DisplayTree) {
    self.backend = backend
    self.tree = tree
  }
}
