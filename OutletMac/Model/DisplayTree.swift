//
//  DisplayTree.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//

import Foundation

/**
 CLASS DisplayTree
 */
class DisplayTree {
  let state: DisplayTreeUiState
  
  init(state: DisplayTreeUiState) {
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

  var rootSPID: SPID {
    get {
      return self.state.rootSN.spid
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

  var rootDeviceUID: UID {
    get {
      return self.state.rootSN.spid.deviceUID
    }
  }

  var treeType: TreeType {
    get {
      return self.state.rootSN.spid.treeType
    }
  }

  var rootSN: SPIDNodePair {
    get {
      return self.state.rootSN
    }
  }

  var hasCheckboxes: Bool {
    get {
      return self.state.hasCheckboxes
    }
  }

  var rootNode: TNode? {
    get {
      return self.state.rootSN.node
    }
  }
}

/**
 CLASS MockDisplayTree
 */
class MockDisplayTree: DisplayTree {
  
}

/**
 CLASS RowsOfInterest
 */
class RowsOfInterest {
  var expanded: Set<GUID>
  var selected: Set<GUID>

  init(expanded: Set<GUID> = Set(), selected: Set<GUID> = Set()) {
    self.expanded = expanded
    self.selected = selected
  }
}

/**
 STRUCT DiffResultTreeIDs
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
 STRUCT DisplayTreeRequest
 Fat Microsoft-style struct encapsulating a bunch of params for request_display_tree()
 */
struct DisplayTreeRequest: CustomStringConvertible {
  let treeID: TreeID
  let returnAsync: Bool
  let deviceUID: UID?
  let userPath: String?
  let spid: SPID?
  let isStartup: Bool
  let treeDisplayMode: TreeDisplayMode
  
  init(treeID: TreeID, returnAsync: Bool, userPath: String? = nil, deviceUID: UID? = nil, spid: SPID? = nil, isStartup: Bool = false,
       treeDisplayMode: TreeDisplayMode = TreeDisplayMode.ONE_TREE_ALL_ITEMS) {
    self.treeID = treeID
    self.returnAsync = returnAsync
    self.deviceUID = deviceUID
    self.userPath = userPath
    self.spid = spid
    self.isStartup = isStartup
    self.treeDisplayMode = treeDisplayMode
  }

  var description: String {
    get {
      return "DisplayTreeRequest(treeID=\(quoted(self.treeID)) spid=\(descOrNil(self.spid)) deviceUID=\(descOrNil(deviceUID)) userPath=\(quotedOrNil(self.userPath)) isStartup='\(self.isStartup)' treeDisplayMode=\(self.treeDisplayMode) returnAsync=\(self.returnAsync))"
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
  
  init(treeID: TreeID, rootSN: SPIDNodePair, rootExists: Bool, offendingPath: String?, needsManualLoad: Bool,
       treeDisplayMode: TreeDisplayMode, hasCheckboxes: Bool) {
    self.treeID = treeID
    /**We require a SPID because a display tree can only have one root path.*/
    self.rootSN = rootSN
    self.rootExists = rootExists
    self.offendingPath = offendingPath
    self.treeDisplayMode = treeDisplayMode
    self.hasCheckboxes = hasCheckboxes
    
    /**If True, the UI should display a "Load" button in order to kick off the backend data load.
     If False; the backend will automatically start loading in the background.*/
    self.needsManualLoad = needsManualLoad
  }

  var description: String {
    get {
      return "DisplayTreeUiState(treeID='\(self.treeID)' rootSN=\(self.rootSN) rootExists=\(self.rootExists) offendingPath='\(self.offendingPath ?? "nil")' needsManualLoad=\(self.needsManualLoad) treeDisplayMode=\(self.treeDisplayMode) hasCheckboxes=\(self.hasCheckboxes))"
    }
  }
  
  func toDisplayTree() -> DisplayTree {
    if self.rootExists {
      return DisplayTree(state: self)
    } else {
      return MockDisplayTree(state: self)
    }
  }
}
