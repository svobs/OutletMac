//
//  NodeIdentifier.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-14.
//

import Foundation

/**
 CLASS NodeIdentifier
 "Abstract" base class. Should not be instantiated.
 */
class NodeIdentifier: CustomStringConvertible {
  let uid: UID
  let deviceUID: UID
  // TODO: when I get better with Swift, pursue union type
  var pathList: [String]
  
  init(_ uid: UID, deviceUID: UID, _ pathList: [String]) {
    self.uid = uid
    self.deviceUID = deviceUID
    self.pathList = pathList
  }
  
  func copy(with uid: UID? = nil) -> NodeIdentifier {
    let uidToCopy: UID = uid ?? self.uid
    return NodeIdentifier(uidToCopy, deviceUID: self.deviceUID, self.pathList)
  }

  public var description: String {
    return "∣\(TreeType.display(treeType))-\(uid)⩨\(pathList)∣"
  }

  var treeType: TreeType {
    get {
      return .NA
    }
  }

  // MARK: SPID
  
  func isSPID() -> Bool {
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
    super.init(NULL_UID, deviceUID: NULL_UID, [])
  }

  override public var description: String {
    return "∣\(TreeType.display(treeType))-\(uid)⩨∣"
  }
}

/**
 CLASS SinglePathNodeIdentifier

 Should not be instantiated! Use child classes only!
 */
class SinglePathNodeIdentifier: NodeIdentifier {
  init(_ uid: UID, deviceUID: UID, _ singlePath: String) {
    super.init(uid, deviceUID: deviceUID, [singlePath])
  }

  override func isSPID() -> Bool {
    return true
  }
  
  override func getSinglePath() -> String {
    self.pathList[0]
  }

  override public var description: String {
    return "∣\(TreeType.display(treeType))-\(uid)⩨\"\(getSinglePath())\"∣"
  }
}

typealias SPID = SinglePathNodeIdentifier

/**
 CLASS GDriveSPID

 A SPID for GDrive nodes
 */
class GDriveSPID: SinglePathNodeIdentifier {

  override func copy(with uid: UID? = nil) -> GDriveSPID {
    let uidToCopy: UID = uid ?? self.uid
    return GDriveSPID(uidToCopy, deviceUID: self.deviceUID, self.getSinglePath())
  }

  override var treeType: TreeType {
    get {
      return TreeType.GDRIVE
    }
  }

  static func from(_ nodeIdentifier: NodeIdentifier, _ singlePath: String) -> GDriveSPID {
    return GDriveSPID(nodeIdentifier.uid, deviceUID: nodeIdentifier.deviceUID, singlePath)
  }
}

/**
 CLASS MixedSPID

 A SPID for Mixed tree types
 */
class MixedSPID: SinglePathNodeIdentifier {

  override func copy(with uid: UID? = nil) -> GDriveSPID {
    let uidToCopy: UID = uid ?? self.uid
    return GDriveSPID(uidToCopy, deviceUID: self.deviceUID, self.getSinglePath())
  }

  static func from(_ nodeIdentifier: NodeIdentifier, _ singlePath: String) -> MixedSPID {
    return MixedSPID(nodeIdentifier.uid, deviceUID: nodeIdentifier.deviceUID, singlePath)
  }

  override var treeType: TreeType {
    get {
      return TreeType.MIXED
    }
  }

}


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
    return GDriveIdentifier(uidToCopy, deviceUID: self.deviceUID, self.pathList)
  }

}

/**
 CLASS LocalNodeIdentifier
 */
class LocalNodeIdentifier: SinglePathNodeIdentifier {
  
  override func copy(with uid: UID? = nil) -> LocalNodeIdentifier {
    let uidToCopy: UID = uid ?? self.uid
    return LocalNodeIdentifier(uidToCopy, deviceUID: self.deviceUID, self.getSinglePath())
  }

  override var treeType: TreeType {
    get {
      return TreeType.LOCAL_DISK
    }
  }

}
