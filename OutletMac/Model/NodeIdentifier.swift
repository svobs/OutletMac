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
class NodeIdentifier: CustomStringConvertible, Equatable {

  init(_ nodeUID: UID, deviceUID: UID, _ pathList: [String]) {
    self.nodeUID = nodeUID
    self.deviceUID = deviceUID
    self.pathList = pathList
  }

  let nodeUID: UID
  let deviceUID: UID
  // TODO: when I get better with Swift, pursue union type
  var pathList: [String]

  public var description: String {
    return "∣\(TreeType.display(treeType))-\(deviceUID):\(nodeUID)⩨\(pathList)∣"
  }

  var treeType: TreeType {
    get {
      return .NA
    }
  }

  var guid: GUID {
    // This MUST match the BE's behavior exactly, or bugs will result!
    return "\(self.deviceUID):\(self.nodeUID)"
  }

  // MARK: SPID
  
  func isSPID() -> Bool {
    false
  }
  
  func getSinglePath() -> String {
    fatalError("Cannot call getSinglePath() for NodeIdentifier base class!")
  }

  func equals(_ rhs: NodeIdentifier) -> Bool {
    return self.deviceUID == rhs.deviceUID && self.nodeUID == rhs.nodeUID
  }

  static func ==(lhs: NodeIdentifier, rhs: NodeIdentifier) -> Bool {
    return lhs.equals(rhs)
  }
}

/**
 CLASS SinglePathNodeIdentifier

 Should not be instantiated! Use child classes only!
 */
class SinglePathNodeIdentifier: NodeIdentifier {

  init(_ nodeUID: UID, deviceUID: UID, _ singlePath: String, parentGUID: GUID? = nil) {
    super.init(nodeUID, deviceUID: deviceUID, [singlePath])
    self.parentGUID = parentGUID
  }

  var parentGUID: GUID?

  var pathUID: UID {
    get {
      // default to nodeUID for LocalDisk, etc, where paths and nodes are 1-to-1
      return self.nodeUID
    }
  }

  override func isSPID() -> Bool {
    return true
  }
  
  override func getSinglePath() -> String {
    self.pathList[0]
  }

  override public var description: String {
    return "∣\(guid)⩨\"\(getSinglePath())\"∣"
  }

  func equals(_ rhs: SinglePathNodeIdentifier) -> Bool {
    return super.equals(_: rhs) && self.getSinglePath() == rhs.getSinglePath()
  }

  static func ==(lhs: SinglePathNodeIdentifier, rhs: SinglePathNodeIdentifier) -> Bool {
    // call into instance func so that it can properly inherit behavior from superclass
    return lhs.equals(rhs)
  }
}

typealias SPID = SinglePathNodeIdentifier

/**
 CLASS EphemeralNodeIdentifier

 This is kind of a kludgy class, designed to get a unique GUID for ephemeral nodes, while avoiding a path UID
 lookup which would be normally required for GDrive trees.

 To accomplish this, I take advantage of the fact that only one ephemeral child can exist for a given parent.
 This class inherits everything from
 */
class EphemeralNodeIdentifier: SinglePathNodeIdentifier {

  init(parent: SinglePathNodeIdentifier?) {
    if parent != nil {
      self._pathUID = parent!.pathUID
      super.init(parent!.nodeUID, deviceUID: parent!.deviceUID, "", parentGUID: parent!.parentGUID)
    } else {
      // root of tree
      self._pathUID = NULL_UID
      super.init(NULL_UID, deviceUID: NULL_UID, "")
    }
  }

  let _pathUID: UID

  override var pathUID: UID {
    get {
      return self._pathUID
    }
  }

  override var guid: GUID {
    return "0:0:\(self._pathUID):E"
  }

  override public var description: String {
    return "∣\(TreeType.display(treeType))-\(guid)∣"
  }
}

/**
 CLASS GDriveSPID

 A SPID for GDrive nodes
 */
class GDriveSPID: SinglePathNodeIdentifier {

  init(_ nodeUID: UID, deviceUID: UID, pathUID: UID, _ singlePath: String, parentGUID: GUID? = nil) {
    self._pathUID = pathUID
    super.init(nodeUID, deviceUID: deviceUID, singlePath, parentGUID: parentGUID)
  }

  let _pathUID: UID

  override var pathUID: UID {
    get {
      return self._pathUID
    }
  }

  override var guid: GUID {
    // This MUST match the BE's behavior exactly, or bugs will result!
    return "\(self.deviceUID):\(self.nodeUID):\(self._pathUID)"
  }

  override public var description: String {
    return "∣\(TreeType.display(treeType))-\(guid)⩨\(self.getSinglePath())∣"
  }

  override var treeType: TreeType {
    get {
      return TreeType.GDRIVE
    }
  }

  func equals(_ rhs: GDriveSPID) -> Bool {
    return super.equals(_: rhs) && self.pathUID == rhs.pathUID
  }

  static func ==(lhs: GDriveSPID, rhs: GDriveSPID) -> Bool {
    return lhs.equals(rhs)
  }
}

/**
 CLASS MixedTreeSPID

 A SPID for Mixed tree types
 */
class MixedTreeSPID: SinglePathNodeIdentifier {
  init(_ nodeUID: UID, deviceUID: UID, pathUID: UID, _ singlePath: String, parentGUID: GUID? = nil) {
    self._pathUID = pathUID
    super.init(nodeUID, deviceUID: deviceUID, singlePath, parentGUID: parentGUID)
  }

  let _pathUID: UID

  override var pathUID: UID {
    get {
      return self._pathUID
    }
  }

  override var guid: GUID {
    // This MUST match the BE's behavior exactly, or bugs will result!
    return "\(self.deviceUID):\(self.nodeUID):\(self._pathUID)"
  }

  override public var description: String {
    return "∣\(TreeType.display(treeType))-\(guid)⩨\(self.getSinglePath())∣"
  }

  override var treeType: TreeType {
    get {
      return TreeType.MIXED
    }
  }

  func equals(_ rhs: MixedTreeSPID) -> Bool {
    return super.equals(_: rhs) && self.pathUID == rhs.pathUID
  }

  static func ==(lhs: MixedTreeSPID, rhs: MixedTreeSPID) -> Bool {
    return lhs.equals(rhs)
  }
}


/**
 CLASS GDriveIdentifier

 NOT a SPID
 */
class GDriveIdentifier: NodeIdentifier {
  override var treeType: TreeType {
    get {
      return .GDRIVE
    }
  }

  public override var description: String {
    return "∣\(TreeType.display(treeType))-\(deviceUID):\(nodeUID):x⩨\(pathList)∣"
  }

}

/**
 CLASS LocalNodeIdentifier
 */
class LocalNodeIdentifier: SinglePathNodeIdentifier {

  override var treeType: TreeType {
    get {
      return TreeType.LOCAL_DISK
    }
  }

}

/**
 CLASS ChangeTreeSPID

 NOTE: path_uid is stored as node_uid for ChangeTreeSPIDs, but node_uid is not used and should not be assumed to be the same value as
 the underlying Node.
 */
class ChangeTreeSPID: SinglePathNodeIdentifier {

  init(pathUID: UID, deviceUID: UID, _ singlePath: String, _ opType: UserOpType?, parentGUID: GUID? = nil) {
    self.opType = opType
    self._path_uid = pathUID
    super.init(NULL_UID, deviceUID: deviceUID, singlePath, parentGUID: parentGUID)
  }

  let _path_uid: UID

  override var pathUID: UID {
    get {
      // default to nodeUID for LocalDisk, etc, where paths and nodes are 1-to-1
      return self._path_uid
    }
  }

  let opType: UserOpType?

  override var treeType: TreeType {
    get {
      // TODO: deprecate tree_type: this is a bad API
      fatalError("Cannot get treeType for ChangeTreeSPID!")
    }
  }

  override var guid: GUID {
    // This MUST match the BE's behavior exactly, or bugs will result!
    if self.opType != nil {
      return "\(self.deviceUID):\(self.opType!):\(self.pathUID)"
    } else {
      return "\(self.deviceUID)"
    }
  }

  func equals(_ rhs: ChangeTreeSPID) -> Bool {
    return super.equals(_: rhs) && self.pathUID == rhs.pathUID && ((self.opType == nil && rhs.opType == nil) || (self.opType == rhs.opType))
  }

  static func ==(lhs: ChangeTreeSPID, rhs: ChangeTreeSPID) -> Bool {
    return lhs.equals(rhs)
  }
}
