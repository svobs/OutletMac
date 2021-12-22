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
  let actionType: ActionType
  let targetGUIDList: [GUID]
  let targetNodeList: [Node]

  init(_ treeID: TreeID, _ actionType: ActionType, _ targetGUIDList: [GUID], _ targetNodeList: [Node]) {
    self.treeID = treeID
    self.actionType = actionType
    self.targetGUIDList = targetGUIDList
    self.targetNodeList = targetNodeList
  }

  func getActionID() -> UInt32 {
    switch actionType {
    case .BUILTIN(let actionID):
      return actionID.rawValue
    case .CUSTOM(let actionID):
      return actionID
    }
  }
}
