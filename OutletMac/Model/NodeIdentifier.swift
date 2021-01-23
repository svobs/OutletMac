//
//  NodeIdentifier.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-14.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

/**
 CLASS NodeIdentifier
 "Abstract" base class. Should not be instantiated.
 */
class NodeIdentifier: CustomStringConvertible {
  let uid: UID
  // TODO: when I get better with Swift, pursue union type
  var pathList: [String]
  
  init(_ uid: UID, _ pathList: [String]) {
    self.uid = uid
    self.pathList = pathList
  }
  
  public var description: String {
    return "\(self.getTreeType().rawValue)-\(uid)⩨\(pathList)∣"
  }
  
  func getTreeType() -> TreeType {
    return .NA
  }
  
  // MARK: SPID
  
  func isSpid() -> Bool {
    false
  }
  
  func isSinglePath() throws -> Bool {
    throw OutletError.invalidOperation
  }
  
  func getSinglePath() throws -> String {
    throw OutletError.invalidOperation
  }
  
}

/**
 CLASS NullNodeIdentifier
 */
class NullNodeIdentifier: NodeIdentifier {
  init() {
    super.init(NULL_UID, [])
  }
}

/**
 CLASS SinglePathNodeIdentifier
 */
class SinglePathNodeIdentifier: NodeIdentifier {
  let treeType: TreeType
  init(_ uid: UID, _ singlePath: String, _ treeType: TreeType) {
    self.treeType = treeType
    super.init(uid, [singlePath])
  }
  
  override func getTreeType() -> TreeType {
    return self.treeType
  }
  
  override func isSpid() -> Bool {
    false
  }
  
  override func isSinglePath() throws -> Bool {
    return true
  }
  
  override func getSinglePath() -> String {
    self.pathList[0]
  }
}

typealias SPID = SinglePathNodeIdentifier


/**
 CLASS GDriveIdentifier
 */
class GDriveIdentifier: NodeIdentifier {
  override func getTreeType() -> TreeType {
    return .GDRIVE
  }
}

/**
 CLASS LocalNodeIdentifier
 */
class LocalNodeIdentifier: SinglePathNodeIdentifier {
  init(_ uid: UID, _ singlePath: String) {
    super.init(uid, singlePath, .LOCAL_DISK)
  }
  
}
