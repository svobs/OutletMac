//
//  TreeAction.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/12/19.
//  Copyright © 2021 Matt Svoboda. All rights reserved.
//

import Foundation

/*
 Generic action
 */
class Action {
  let actionType: ActionType

  init(_ actionType: ActionType) {
    self.actionType = actionType
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

class GlobalAction: Action {
}

/*
 An action whose context is confined to a particular tree in the UID
 */
class TreeAction: Action {
  let treeID: TreeID
  let targetGUIDList: [GUID]
  let targetNodeList: [Node]

  init(_ treeID: TreeID, _ actionType: ActionType, _ targetGUIDList: [GUID], _ targetNodeList: [Node]) {
    self.treeID = treeID
    self.targetGUIDList = targetGUIDList
    self.targetNodeList = targetNodeList
    super.init(actionType)
  }
}
