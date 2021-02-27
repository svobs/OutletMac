//
//  DisplayStore.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

/**
 I suppose this class a repository for "ModelView" objects in the MVVC design pattern.
 */
class DisplayStore {
  private var con: TreeControllable

  private var parentChildListDict: [UID: [Node]] = [:]
  private var treeNodeDict: [UID: Node] = [:]

  init(_ controllable: TreeControllable) {
    self.con = controllable
  }

  func repopulateRoot(_ topLevelNodeList: [Node]) {
    con.app.execSync {
      var nodeDict: [UID: Node] = [:]
      for node in topLevelNodeList {
        nodeDict[node.uid] = node
      }

      self.treeNodeDict = nodeDict
      self.parentChildListDict.removeAll()
      self.parentChildListDict[NULL_UID] = topLevelNodeList
    }
  }

  func populateChildList(_ parentUID: UID, _ childList: [Node]) {
    con.app.execSync {
      for child in childList {
        self.treeNodeDict[child.uid] = child
      }
      self.parentChildListDict[parentUID] = childList
    }
  }

  func getNode(_ uid: UID) -> Node? {
    var node: Node?
    con.app.execSync {
      node = self.treeNodeDict[uid] ?? nil
    }
    return node
  }

  func getChildList(_ parentUID: UID?) -> [Node] {
    var nodeList: [Node] = []
    con.app.execSync {
      nodeList = self.parentChildListDict[parentUID ?? NULL_UID] ?? []
    }
    return nodeList
  }

  func getChild(_ parentUID: UID?, _ childIndex: Int) -> Node? {
    var node: Node?
    con.app.execSync {
      let childList = self.parentChildListDict[parentUID ?? NULL_UID] ?? []
      if childIndex >= childList.count {
        NSLog("ERROR Could not find child of parent UID \(parentUID ?? NULL_UID) & index \(childIndex)")
        node = nil
      } else {
        node = childList[childIndex]
      }
    }
    return node
  }
}
