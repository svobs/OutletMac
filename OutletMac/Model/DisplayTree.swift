//
//  DisplayTree.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation


/**
 CLASS DisplayTree
 */
class DisplayTree {
  let backend: OutletBackend
  let state: DisplayTreeUiState
  
  init(backend: OutletBackend, state: DisplayTreeUiState) {
    self.backend = backend
    self.state = state
  }

  var treeID: String {
    get {
      return self.state.treeID
    }
  }
}

/**
 CLASS NullDisplayTree
 */
class NullDisplayTree: DisplayTree {
  
}

/**
 CLASS DiffResultTreeIDs
 */
class DiffResultTreeIDs {
  let treeIDLeft: String
  let treeIDRight: String
  
  init(left treeIDLeft: String, right treeIDRight: String) {
    self.treeIDLeft = treeIDLeft
    self.treeIDRight = treeIDRight
  }
}


/**
 CLASS DisplayTreeRequest
 Fat Microsoft-style struct encapsulating a bunch of params for request_display_tree()
 */
class DisplayTreeRequest {
  let treeID: String
  let returnAsync: Bool
  let userPath: String?
  let spid: SPID?
  let isStartup: Bool
  let treeDisplayMode: TreeDisplayMode
  
  init(treeID: String, returnAsync: Bool, userPath: String? = nil, spid: SPID? = nil, isStartup: Bool = false,
       treeDisplayMode: TreeDisplayMode = TreeDisplayMode.ONE_TREE_ALL_ITEMS) {
    self.treeID = treeID
    self.returnAsync = returnAsync
    self.userPath = userPath
    self.spid = spid
    self.isStartup = isStartup
    self.treeDisplayMode = treeDisplayMode
  }
}

/**
 CLASS DisplayTreeUiState
 */
class DisplayTreeUiState: CustomStringConvertible {
  
  let treeID: String
  let rootSN: SPIDNodePair
  let rootExists: Bool
  let offendingPath: String?
  let treeDisplayMode: TreeDisplayMode
  let hasCheckboxes: Bool
  let needsManualLoad: Bool
  
  init(treeID: String, rootSN: SPIDNodePair, rootExists: Bool, offendingPath: String? = nil,
       treeDisplayMode: TreeDisplayMode = TreeDisplayMode.ONE_TREE_ALL_ITEMS, hasCheckboxes: Bool = false) {
    self.treeID = treeID
    /**SPIDNodePair is needed to clarify the (albeit very rare) case where the root node resolves to multiple paths.
     Each display tree can only have one root path.*/
    self.rootSN = rootSN
    self.rootExists = rootExists
    self.offendingPath = offendingPath
    self.treeDisplayMode = treeDisplayMode
    self.hasCheckboxes = hasCheckboxes
    
    /**If True, the UI should display a "Load" button in order to kick off the backend data load.
     If False; the backend will automatically start loading in the background.*/
    self.needsManualLoad = false
  }

  var description: String {
    get {
      return "DisplayTreeUiState(treeID='\(self.treeID)' rootSN=\(self.rootSN) rootExists=\(self.rootExists) offendingPath='\(self.offendingPath ?? "null")' treeDisplayMode=\(self.treeDisplayMode) hasCheckboxes=\(self.hasCheckboxes))"
    }
  }
  
  func toDisplayTree(backend: OutletBackend) -> DisplayTree {
    if self.rootExists {
      return DisplayTree(backend: backend, state: self)
    } else {
      return NullDisplayTree(backend: backend, state: self)
    }
  }
}
