//
//  UserOp.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-24.
//  Copyright © 2021 Ibotta. All rights reserved.
//

enum UserOpType: UInt32 {
  case RM = 1  // Remove src node
  case CP = 2  // Copy content of src node to dst node
  case MKDIR = 3 // Make dir represented by src node
  case MV = 4 // Equivalent to CP followed by RM: copy src node to dst node, then delete src node
  case UP = 5 // Essentially equivalent to CP, but intention is different. Copy content of src node to dst node, overwriting the contents of dst
  
  static let DISPLAYED_USER_OP_TYPES: [UserOpType: String] = [
    UserOpType.CP: "To Add",
    UserOpType.RM: "To Delete",
    UserOpType.UP: "To Update",
    UserOpType.MV: "To Move"
  ]

 func hasDst() -> Bool {
  return self == .CP || self == .MV || self == .UP
 }
}

enum UserOpStatus: UInt32 {
  case NOT_STARTED = 1
  case EXECUTING = 2
  case STOPPED_ON_ERROR = 8
  case COMPLETED_NO_OP = 9
  case COMPLETED_OK = 10
}

class UserOp: CustomStringConvertible {
  let opUID: UID
  let batchUID: UID
  let opType: UserOpType
  var srcNode: Node
  var dstNode: Node?
  let createTS: UInt64
  
  init(opUID: UID, batchUID: UID, opType: UserOpType, srcNode: Node, dstNode: Node? = nil, createTS: UInt64? = nil) {
    self.opUID = opUID
    self.batchUID = batchUID
    self.opType = opType
    self.srcNode = srcNode
    self.dstNode = dstNode
    self.createTS = createTS ?? DateUtil.getCurrentTimeMS()
  }
  
  func hasDst() -> Bool {
    return self.opType.hasDst()
  }
  
  var description: String {
    let dstStr: String = dstNode == nil ? "null" : dstNode!.description
    return "UserOp(opUID=\(opUID) batch=\(batchUID) type=\(opType) src=\(srcNode) dst=\(dstStr))"
  }
}
