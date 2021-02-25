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
  private var con: TreeControllable? = nil

  private var parentChildListDict: [UID: [Node]] = [:]
  private var treeNodeDict: [UID: Node] = [:]

  init(_ controllable: TreeControllable) {
    self.con = controllable
  }

  // TODO: make thread-safe
  func repopulateRoot(_ topLevelNodeList: [Node]) {
    var nodeDict: [UID: Node] = [:]
    for node in topLevelNodeList {
      nodeDict[node.uid] = node
    }

    self.treeNodeDict = nodeDict
    self.parentChildListDict.removeAll()
    self.parentChildListDict[NULL_UID] = topLevelNodeList
  }

  func populateChildList(_ parentUID: UID, _ childList: [Node]) {
    for child in childList {
      treeNodeDict[child.uid] = child
    }
    self.parentChildListDict[parentUID] = childList
  }

  func getNode(_ uid: UID) -> Node? {
    return treeNodeDict[uid] ?? nil
  }

  func getChildList(_ parentUID: UID?) -> [Node] {
    let parent = parentUID ?? NULL_UID
    return parentChildListDict[parent] ?? []
  }

  func getChild(_ parentUID: UID?, _ childIndex: Int) -> Node? {
    let childList = getChildList(parentUID)
    if childIndex >= childList.count {
      NSLog("ERROR Could not find child of parent UID \(parentUID ?? NULL_UID) & index \(childIndex)")
      return nil
    }
    return childList[childIndex]
  }
}
