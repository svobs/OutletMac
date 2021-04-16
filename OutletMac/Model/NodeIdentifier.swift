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
  let nodeUID: UID
  let deviceUID: UID
  // TODO: when I get better with Swift, pursue union type
  var pathList: [String]
  
  init(_ nodeUID: UID, deviceUID: UID, _ pathList: [String]) {
    self.nodeUID = nodeUID
    self.deviceUID = deviceUID
    self.pathList = pathList
  }
  
  func copy(with nodeUID: UID? = nil) -> NodeIdentifier {
    let uidToCopy: UID = nodeUID ?? self.nodeUID
    return NodeIdentifier(uidToCopy, deviceUID: self.deviceUID, self.pathList)
  }

  public var description: String {
    return "∣\(TreeType.display(treeType))-D\(deviceUID)-N\(nodeUID)⩨\(pathList)∣"
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
  
  func getSinglePath() throws -> String {
    throw OutletError.invalidOperation("Cannot call getSinglePath() for NodeIdentifier base class!")
  }
}

/**
 CLASS SinglePathNodeIdentifier

 Should not be instantiated! Use child classes only!
 */
class SinglePathNodeIdentifier: NodeIdentifier {
  init(_ nodeUID: UID, deviceUID: UID, _ singlePath: String) {
    super.init(nodeUID, deviceUID: deviceUID, [singlePath])
  }

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
    return "∣\(TreeType.display(treeType))-\(nodeUID)⩨\"\(getSinglePath())\"∣"
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
  let _pathUID: UID

  init(parent: SinglePathNodeIdentifier?) {
    if parent != nil {
      self._pathUID = parent!.pathUID
      super.init(parent!.nodeUID, deviceUID: parent!.deviceUID, "")
    } else {
      // root of tree
      self._pathUID = NULL_UID
      super.init(NULL_UID, deviceUID: NULL_UID, "")
    }
  }

  override var pathUID: UID {
    get {
      return self._pathUID
    }
  }

  override var guid: GUID {
    return "\(self.deviceUID):\(self.nodeUID):\(self._pathUID):E"
  }

  override public var description: String {
    return "∣\(TreeType.display(treeType))-D\(deviceUID)-N\(nodeUID)-P\(pathUID)⩨∣"
  }
}

/**
 CLASS GDriveSPID

 A SPID for GDrive nodes
 */
class GDriveSPID: SinglePathNodeIdentifier {
  let _pathUID: UID

  override var pathUID: UID {
    get {
      return self._pathUID
    }
  }

  init(_ nodeUID: UID, deviceUID: UID, pathUID: UID, _ singlePath: String) {
    self._pathUID = pathUID
    super.init(nodeUID, deviceUID: deviceUID, singlePath)
  }

  override var guid: GUID {
    // This MUST match the BE's behavior exactly, or bugs will result!
    return "\(self.deviceUID):\(self.nodeUID):\(self._pathUID)"
  }

  override func copy(with nodeUID: UID? = nil) -> GDriveSPID {
    let uidToCopy: UID = nodeUID ?? self.nodeUID
    return GDriveSPID(uidToCopy, deviceUID: self.deviceUID, pathUID: self._pathUID, self.getSinglePath())
  }

  override public var description: String {
    return "∣\(TreeType.display(treeType))-D\(deviceUID)-N\(nodeUID)-P\(pathUID)⩨\(pathList)∣"
  }

  override var treeType: TreeType {
    get {
      return TreeType.GDRIVE
    }
  }

}

/**
 CLASS MixedSPID

 A SPID for Mixed tree types
 */
class MixedSPID: SinglePathNodeIdentifier {

  override func copy(with uid: UID? = nil) -> MixedSPID {
    let uidToCopy: UID = uid ?? self.nodeUID
    return MixedSPID(uidToCopy, deviceUID: self.deviceUID, self.getSinglePath())
  }

  static func from(_ nodeIdentifier: NodeIdentifier, _ singlePath: String) -> MixedSPID {
    return MixedSPID(nodeIdentifier.nodeUID, deviceUID: nodeIdentifier.deviceUID, singlePath)
  }

  override var treeType: TreeType {
    get {
      return TreeType.MIXED
    }
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

  var pathUID: UID {
    get {
      // don't ever do this
      fatalError("Cannot get pathUID for GDriveIdentifier!")
    }
  }

  override func copy(with nodeUID: UID? = nil) -> GDriveIdentifier {
    let uidToCopy: UID = nodeUID ?? self.nodeUID
    return GDriveIdentifier(uidToCopy, deviceUID: self.deviceUID, self.pathList)
  }

}

/**
 CLASS LocalNodeIdentifier
 */
class LocalNodeIdentifier: SinglePathNodeIdentifier {
  
  override func copy(with nodeUID: UID? = nil) -> LocalNodeIdentifier {
    let uidToCopy: UID = nodeUID ?? self.nodeUID
    return LocalNodeIdentifier(uidToCopy, deviceUID: self.deviceUID, self.getSinglePath())
  }

  override var treeType: TreeType {
    get {
      return TreeType.LOCAL_DISK
    }
  }

}
