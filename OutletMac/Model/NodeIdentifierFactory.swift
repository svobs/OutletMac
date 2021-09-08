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

  func forValues(_ uid: UID, deviceUID: UID, _ pathList: [String], pathUID: UID, opType: UInt32, parentGUID: GUID) throws -> NodeIdentifier {
    if deviceUID == NULL_UID {
      // this can indicate that the entire node doesn't exist or is invalid
      throw OutletError.invalidState("device_uid cannot be null!")
    }

    let parentGUID = parentGUID == "" ? nil : parentGUID

    if opType > 0 {
      // ChangeTreeSPID (we must be coming from gRPC)
      let opTypeEnum: UserOpType?
      if opType == GRPC_CHANGE_TREE_NO_OP {
        opTypeEnum = nil
      } else {
        opTypeEnum = UserOpType(rawValue: opType)
      }
      return ChangeTreeSPID(pathUID: pathUID, deviceUID: deviceUID, pathList[0], opTypeEnum, parentGUID: parentGUID)
    }

    let treeType = try self.getTreeType(for: deviceUID)

    if treeType == .LOCAL_DISK {
      // LocalNodeIdentifier is always a SPID
      return LocalNodeIdentifier(uid, deviceUID: deviceUID, pathList[0], parentGUID: parentGUID)
    } else if treeType == .GDRIVE {
      if pathUID > NULL_UID { // non-null value indicates that it must be single path
        if pathList.count > 1 {
            throw OutletError.invalidState("NodeIdentifierFactory.forAllValues(): mustBeSinglePath=true but paths count is: \(pathList.count)")
        }
        return GDriveSPID(uid, deviceUID: deviceUID, pathUID: pathUID, pathList[0], parentGUID: parentGUID)
      }
      return GDriveIdentifier(uid, deviceUID: deviceUID, pathList)
    } else if treeType == .MIXED {
      if pathList.count > 1 {
        throw OutletError.invalidState("Too many paths for tree_type MIXED: \(pathList)")
      }
      if deviceUID != SUPER_ROOT_DEVICE_UID {
        throw OutletError.invalidState("Expected deviceUID of \(SUPER_ROOT_DEVICE_UID) but found \(deviceUID)")
      }
      if pathUID == NULL_UID {
        throw OutletError.invalidState("PathUID is null!")
      }
      return MixedTreeSPID(uid, deviceUID: deviceUID, pathUID: pathUID, pathList[0], parentGUID: parentGUID)
    }
    
    throw OutletError.invalidState("NodeIdentifierFactory.forAllValues(): bad combination of values: uid=\(uid), deviceUID=\(deviceUID), treeType=\(treeType), pathList=\(pathList), pathUID=\(pathUID)")
  }

}
