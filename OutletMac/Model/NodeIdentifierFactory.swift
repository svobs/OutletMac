//
//  NodeIdentifierFactory.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//

import Foundation

class NodeIdentifierFactory {
  weak var backend: OutletBackend! = nil

  func getDeviceList() throws -> [Device] {
    return backend.app.globalState.deviceList
  }

  // TODO: this is TEMPORARY until we support multiple drives
  func getDefaultLocalDeviceUID() throws -> UID {
    var deviceUID: UID? = nil
    for device in try self.getDeviceList() {
      if device.treeType == .LOCAL_DISK {
        if deviceUID != nil {
          throw OutletError.invalidState("Multiple local disks found but this is not supported!")
        } else {
          deviceUID = device.uid
        }
      }
    }
    if deviceUID == nil {
      throw OutletError.invalidState("No local disks found!")
    } else {
      return deviceUID!
    }
  }

  func getTreeType(for deviceUID: UID) throws -> TreeType {
    guard deviceUID != NULL_UID else {
      throw OutletError.invalidState("getTreeType(): deviceUID is null!")
    }

    if deviceUID == SUPER_ROOT_DEVICE_UID {
      // super-root
      return .MIXED
    }

    for device in try self.getDeviceList() {
      if device.uid == deviceUID {
        return device.treeType
      }
    }
    throw OutletError.invalidState("Could not find device with UID: \(deviceUID)")
  }

  func getRootConstantGDriveIdentifier(_ deviceUID: UID) -> GDriveIdentifier {
    return GDriveIdentifier(GDRIVE_ROOT_UID, deviceUID: deviceUID, [ROOT_PATH])
  }
  
  func getRootConstantGDriveSPID(_ deviceUID: UID) -> SinglePathNodeIdentifier {
    return GDriveSPID(GDRIVE_ROOT_UID, deviceUID: deviceUID, pathUID: ROOT_PATH_UID, ROOT_PATH)
  }
  
  func getRootConstantLocalDiskSPID(_ deviceUID: UID) -> SinglePathNodeIdentifier {
    return LocalNodeIdentifier(LOCAL_ROOT_UID, deviceUID: deviceUID, ROOT_PATH)
  }

  func buildNodeID(_ nodeUID: UID, deviceUID: UID, _ identifierType: NodeIdentifierType, _ pathList: [String]) throws -> NodeIdentifier {
    if deviceUID == NULL_UID {
      // this can indicate that the entire node doesn't exist or is invalid
      throw OutletError.invalidState("device_uid cannot be null!")
    }

    switch identifierType {
    case .GDRIVE_MPID:
      return GDriveIdentifier(nodeUID, deviceUID: deviceUID, pathList)
    default:
      throw OutletError.invalidState("Invalid identifierType for MPID: \(identifierType) (deviceUID=\(deviceUID) nodeUID=\(nodeUID))")
    }
  }

  func buildSPID(_ nodeUID: UID, deviceUID: UID, _ identifierType: NodeIdentifierType, _ singlePath: String, pathUID: UID, parentGUID: GUID) throws
          -> SPID {

    let parentGUID = parentGUID == "" ? nil : parentGUID

    switch identifierType {
    case .LOCAL_DISK_SPID:
      return LocalNodeIdentifier(nodeUID, deviceUID: deviceUID, singlePath, parentGUID: parentGUID)
    case .GDRIVE_SPID:
      return GDriveSPID(nodeUID, deviceUID: deviceUID, pathUID: pathUID, singlePath, parentGUID: parentGUID)
    case .MIXED_TREE_SPID:
      if deviceUID != SUPER_ROOT_DEVICE_UID {
        throw OutletError.invalidState("Expected deviceUID of \(SUPER_ROOT_DEVICE_UID) but found \(deviceUID)")
      }
      if pathUID == NULL_UID {
        throw OutletError.invalidState("PathUID cannot be null for MIXED_TREE_SPID!")
      }
      return MixedTreeSPID(nodeUID, deviceUID: deviceUID, pathUID: pathUID, singlePath, parentGUID: parentGUID)
    default:
      // Must be a category of ChangeTreeSPID
      guard let category = ChangeTreeCategory(rawValue: identifierType.rawValue) else {
        throw OutletError.invalidState("Invalid identifierType for SPID: \(identifierType) (deviceUID=\(deviceUID) nodeUID=\(nodeUID))")
      }
      return ChangeTreeSPID(pathUID: pathUID, deviceUID: deviceUID, singlePath, category, parentGUID: parentGUID)
    }
  }
}
