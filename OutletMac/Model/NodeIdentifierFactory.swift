//
//  NodeIdentifierFactory.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class NodeIdentifierFactory {
  static func getRootConstantGDriveIdentifier() -> GDriveIdentifier {
    return GDriveIdentifier(GDRIVE_ROOT_UID, [ROOT_PATH])
  }
  
  static func getRootConstantSPID(treeType: TreeType) throws -> SinglePathNodeIdentifier {
    switch treeType {
    case .GDRIVE:
      return NodeIdentifierFactory.getRootConstantGDriveSPID()
    case .LOCAL_DISK:
      return NodeIdentifierFactory.getRootConstantLocalDiskSPID()
    case .MIXED:
      return SinglePathNodeIdentifier(SUPER_ROOT_UID, ROOT_PATH, .MIXED)
    case .NA:
      throw OutletError.invalidState
    }
  }
  
  static func getRootConstantGDriveSPID() -> SinglePathNodeIdentifier {
    return SinglePathNodeIdentifier(GDRIVE_ROOT_UID, ROOT_PATH, .GDRIVE)
  }
  
  static func getRootConstantLocalDiskSPID() -> SinglePathNodeIdentifier {
    return SinglePathNodeIdentifier(LOCAL_ROOT_UID, ROOT_PATH, .LOCAL_DISK)
  }
  
  static func forAllValues(_ uid: UID, _ treeType: TreeType, _ pathList: [String], mustBeSinglePath: Bool) throws -> NodeIdentifier {
    if treeType == .LOCAL_DISK {
      // LocalNodeIdentifier is always a SPID
      return LocalNodeIdentifier(uid, pathList[0])
    } else if mustBeSinglePath {
      if pathList.count <= 1 {
        return SinglePathNodeIdentifier(uid, pathList[0], .MIXED)
      } else {
        // TODO: informative error msg
        throw OutletError.invalidState
      }
    } else if treeType == .GDRIVE {
      return GDriveIdentifier(uid, pathList)
    }
    
    // TODO: informative error msg
    throw OutletError.invalidState
  }
}
