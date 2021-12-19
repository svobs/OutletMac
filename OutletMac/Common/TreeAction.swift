//
//  TreeAction.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/12/19.
//  Copyright © 2021 Matt Svoboda. All rights reserved.
//

import Foundation

class TreeAction {
  let treeID: TreeID
  let actionID: ActionID
  let targetGUIDList: [GUID]
  let targetNodeList: [Node]

  init(_ treeID: TreeID, _ actionID: ActionID, _ targetGUIDList: [GUID], _ targetNodeList: [Node]) {
    self.treeID = treeID
    self.actionID = actionID
    self.targetGUIDList = targetGUIDList
    self.targetNodeList = targetNodeList
  }
}
