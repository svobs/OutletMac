//
//  UserOp.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-24.
//


/*
See equivalent backend code for better documentation.
*/
enum UserOpType: UInt32 {
  // --- 1-digit enum = 1 node op ---
  case RM = 1             // Remove src node: file or empty dir
  case MKDIR = 2          // Make dir represented by src node
  case UNLINK = 3         // Will (a) just remove from parent, for GDrive nodes, or (b) unlink shortcuts/links, if those type

  // --- 2-node ops ---
  case CP = 10            // Copy content of src node to dst node (where dst node does not currently exist)
  case CP_ONTO = 11       // Copy content of src node to existing dst node, overwriting the previous contents of dst
  case START_DIR_CP = 12
  case FINISH_DIR_CP = 13

  case MV = 20            // Equivalent to CP followed by RM: copy src node to dst node, then delete src node
  case MV_ONTO = 21       // Copy content of src node to dst node, overwriting the contents of dst, then delete src
  case START_DIR_MV = 22
  case FINISH_DIR_MV = 23

  case CREATE_LINK = 30   // Create a link at dst which points to src.

  
  static let DISPLAYED_USER_OP_TYPES: [UserOpType: String] = [
    UserOpType.CP: "To Add",
    UserOpType.RM: "To Delete",
    UserOpType.CP_ONTO: "To Update",
    UserOpType.MV: "To Move"
  ]

  func hasDst() -> Bool {
    return self.rawValue >= 10
  }
}

enum UserOpStatus: UInt32 {
  case NOT_STARTED = 1
  case EXECUTING = 2
  case BLOCKED_BY_ERROR = 3
  case STOPPED_ON_ERROR = 4

  case COMPLETED_OK = 10
  case COMPLETED_NO_OP = 11
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
