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
  
  func copy(with uid: UID? = nil) -> NodeIdentifier {
    let uidToCopy: UID = uid ?? self.uid
    return NodeIdentifier(uidToCopy, self.pathList)
  }

  public var description: String {
    return "\(TreeType.display(self.treeType))-\(uid)⩨\(pathList)∣"
  }
  
  var treeType: TreeType {
    get {
      return .NA
    }
  }

  // MARK: SPID
  
  func isSpid() -> Bool {
    false
  }
  
  func getSinglePath() throws -> String {
    throw OutletError.invalidOperation("Cannot call getSinglePath() for NodeIdentifier base class!")
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
  var _treeType: TreeType
  init(_ uid: UID, _ singlePath: String, _ treeType: TreeType) {
    self._treeType = treeType
    super.init(uid, [singlePath])
  }
  
  override func copy(with uid: UID? = nil) -> SinglePathNodeIdentifier {
    let uidToCopy: UID = uid ?? self.uid
    return SinglePathNodeIdentifier(uidToCopy, self.getSinglePath(), self.treeType)
  }
  
  override var treeType: TreeType {
    get {
      return self._treeType
    }
    set (treeType) {
      self._treeType = treeType
    }
  }

  override func isSpid() -> Bool {
    false
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
  override var treeType: TreeType {
    get {
      return .GDRIVE
    }
  }
  
  override func copy(with uid: UID? = nil) -> GDriveIdentifier {
    let uidToCopy: UID = uid ?? self.uid
    return GDriveIdentifier(uidToCopy, self.pathList)
  }

}

/**
 CLASS LocalNodeIdentifier
 */
class LocalNodeIdentifier: SinglePathNodeIdentifier {
  init(_ uid: UID, _ singlePath: String) {
    super.init(uid, singlePath, .LOCAL_DISK)
  }
  
  override func copy(with uid: UID? = nil) -> LocalNodeIdentifier {
    let uidToCopy: UID = uid ?? self.uid
    return LocalNodeIdentifier(uidToCopy, self.getSinglePath())
  }
}
