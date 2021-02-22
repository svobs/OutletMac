//
//  DisplayTree.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

typealias TreeID = String

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

  var treeID: TreeID {
    get {
      return self.state.treeID
    }
  }

  var needsManualLoad: Bool {
    get {
      return self.state.needsManualLoad
    }
  }

  var rootPath: String {
    get {
      return self.state.rootSN.spid.getSinglePath()
    }
  }

  var rootExists: Bool {
    get {
      return self.state.rootExists
    }
  }

  var treeType: TreeType {
    get {
      return self.state.rootSN.spid.treeType
    }
  }

  var rootNode: Node? {
    get {
      return self.state.rootSN.node
    }
  }

  func getChildListForRoot() throws -> [Node] {
    let rootNode = self.rootNode
    if rootNode == nil {
      NSLog("DEBUG [\(treeID)] Root does not exist; returning empty child list")
      return []
    } else {
      NSLog("DEBUG [\(treeID)] Getting child list for root: \(rootNode!.uid)")
      return try self.getChildList(rootNode!)
    }
  }

  func getChildList(_ parentNode: Node) throws -> [Node] {
    return try self.backend.getChildList(parent: parentNode, treeID: self.treeID)
  }
}

/**
 CLASS MockDisplayTree
 */
class MockDisplayTree: DisplayTree {
  
}

/**
 CLASS DiffResultTreeIDs
 */
struct DiffResultTreeIDs {
  let treeIDLeft: String
  let treeIDRight: String
  
  init(left treeIDLeft: TreeID, right treeIDRight: TreeID) {
    self.treeIDLeft = treeIDLeft
    self.treeIDRight = treeIDRight
  }
}

/**
 CLASS DisplayTreeRequest
 Fat Microsoft-style struct encapsulating a bunch of params for request_display_tree()
 */
struct DisplayTreeRequest: CustomStringConvertible {
  let treeID: TreeID
  let returnAsync: Bool
  let userPath: String?
  let spid: SPID?
  let isStartup: Bool
  let treeDisplayMode: TreeDisplayMode
  
  init(treeID: TreeID, returnAsync: Bool, userPath: String? = nil, spid: SPID? = nil, isStartup: Bool = false,
       treeDisplayMode: TreeDisplayMode = TreeDisplayMode.ONE_TREE_ALL_ITEMS) {
    self.treeID = treeID
    self.returnAsync = returnAsync
    self.userPath = userPath
    self.spid = spid
    self.isStartup = isStartup
    self.treeDisplayMode = treeDisplayMode
  }

  var description: String {
    get {
      return "DisplayTreeRequest(treeID=\(quoted(self.treeID)) spid=\(descOrNil(self.spid)) userPath=\(quotedOrNil(self.userPath)) isStartup='\(self.isStartup)' treeDisplayMode=\(self.treeDisplayMode) returnAsync=\(self.returnAsync))"
    }
  }
}

/**
 CLASS DisplayTreeUiState
 */
class DisplayTreeUiState: CustomStringConvertible {
  let treeID: TreeID
  let rootSN: SPIDNodePair
  let rootExists: Bool
  let offendingPath: String?
  let needsManualLoad: Bool
  let treeDisplayMode: TreeDisplayMode
  let hasCheckboxes: Bool
  
  init(treeID: TreeID, rootSN: SPIDNodePair, rootExists: Bool, offendingPath: String? = nil,
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
      return "DisplayTreeUiState(treeID='\(self.treeID)' rootSN=\(self.rootSN) rootExists=\(self.rootExists) offendingPath='\(self.offendingPath ?? "nil")' treeDisplayMode=\(self.treeDisplayMode) hasCheckboxes=\(self.hasCheckboxes))"
    }
  }
  
  func toDisplayTree(backend: OutletBackend) -> DisplayTree {
    if self.rootExists {
      return DisplayTree(backend: backend, state: self)
    } else {
      return MockDisplayTree(backend: backend, state: self)
    }
  }
}
