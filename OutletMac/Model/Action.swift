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
class Action: CustomStringConvertible {
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

  var description: String {
    switch actionType {
    case .BUILTIN(let actionID):
      return "\(actionID)"
    case .CUSTOM(let actionID):
      return "CUSTOM:\(actionID)"
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
  let targetUID: UID  // use NULL_UID to signify null

  init(_ treeID: TreeID, _ actionType: ActionType, _ targetGUIDList: [GUID], _ targetNodeList: [Node], targetUID: UID = NULL_UID) {
    self.treeID = treeID
    self.targetGUIDList = targetGUIDList
    self.targetNodeList = targetNodeList
    self.targetUID = targetUID
    super.init(actionType)
  }
}
