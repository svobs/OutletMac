//
//  NodeIdentifierFactory.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//

import Foundation

class NodeIdentifierFactory {
  let backend: OutletBackend
  // cache device list
  var deviceList: [Device] = []

  init(_ backend: OutletBackend) {
    self.backend = backend
  }

  func getTreeType(for deviceUID: UID) throws -> TreeType {
    if deviceList.count == 0 {
      // lazy load device list from server.
      // note: it is especially important to use DispatchQueue here, because else we will run risk of crashing if we call a gRPC from the body
      // of another gRPC call
      try DispatchQueue.global(qos: .userInitiated).sync { [unowned self] in
        self.deviceList = try self.backend.getDeviceList()
      }
    }
    for device in self.deviceList {
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
    // disabled this check cuz I'm abusing this method a bit to make it work with EmptyNodes
//    assert(nodeIdentifier.pathList.contains(singlePath), "NodeIdentifier (\(nodeIdentifier)) does not contain path (\(singlePath))")
    return try self.forValues(nodeIdentifier.uid, deviceUID: nodeIdentifier.deviceUID, [singlePath], mustBeSinglePath: true)
      as! SinglePathNodeIdentifier
  }
}
