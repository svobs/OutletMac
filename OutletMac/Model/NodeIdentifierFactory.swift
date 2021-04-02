//
//  NodeIdentifierFactory.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//

import Foundation

class NodeIdentifierFactory {
  let backend: OutletBackend
  init(_ backend: OutletBackend) {
    self.backend = backend
  }

  func getTreeType(for deviceUID: UID) throws -> TreeType {
    for device in try self.backend.getDeviceList() {
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
    return GDriveSPID(GDRIVE_ROOT_UID, deviceUID: deviceUID, ROOT_PATH)
  }
  
  func getRootConstantLocalDiskSPID(_ deviceUID: UID) -> SinglePathNodeIdentifier {
    return LocalNodeIdentifier(LOCAL_ROOT_UID, deviceUID: deviceUID, ROOT_PATH)
  }

  func forValues(_ uid: UID, deviceUID: UID, _ pathList: [String], mustBeSinglePath: Bool) throws -> NodeIdentifier {
    let treeType = try self.getTreeType(for: deviceUID)

    if treeType == .LOCAL_DISK {
      // LocalNodeIdentifier is always a SPID
      return LocalNodeIdentifier(uid, deviceUID: deviceUID, pathList[0])
    } else if treeType == .GDRIVE {
      if mustBeSinglePath {
        if pathList.count > 1 {
            throw OutletError.invalidState("NodeIdentifierFactory.forAllValues(): mustBeSinglePath=true but paths count is: \(pathList.count)")
        }
        return GDriveSPID(uid, deviceUID: deviceUID, pathList[0])
      }
      return GDriveIdentifier(uid, deviceUID: deviceUID, pathList)
    }
    
    throw OutletError.invalidState("NodeIdentifierFactory.forAllValues(): bad combination of values: uid=\(uid), deviceUID=\(deviceUID), treeType=\(treeType), pathList=\(pathList), mustBeSinglePath=\(mustBeSinglePath)")
  }

  func singlePath(from nodeIdentifier: NodeIdentifier, with singlePath: String) throws -> SinglePathNodeIdentifier {
    assert(nodeIdentifier.pathList.contains(singlePath), "NodeIdentifier (\(nodeIdentifier)) does not contain path (\(singlePath))")
    return try self.forValues(nodeIdentifier.uid, deviceUID: nodeIdentifier.deviceUID, [singlePath], mustBeSinglePath: true)
      as! SinglePathNodeIdentifier
  }
}
