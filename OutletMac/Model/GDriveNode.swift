//
//  GDriveNode.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-20.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

typealias GoogID = String

/**
 CLASS GDriveNode
 */
class GDriveNode: Node {
  var googID: GoogID?
  var _name: String
  override var name: String {
    get {
      return _name
    }
  }
  
  var createTS: UInt64?
  var _modifyTS: UInt64?
  override var modifyTS: UInt64? {
    get {
      return _modifyTS
    }
    set (modifyTS) {
      self._modifyTS = modifyTS
    }
  }
  
  var _syncTS: UInt64?
  override var syncTS: UInt64? {
    get {
      return _syncTS
    }
    set (syncTS) {
      self._syncTS = syncTS
    }
  }
  
  var ownerUID: UID
  
  /**This will only ever contain other users' drive_ids.*/
  var driveID: String?
  
  var sharedByUserUID: UID?
  
  /**If true, item is shared by shared_by_user_uid*/
  var _isShared: Bool
  override var isShared: Bool {
    get {
      return _isShared
    }
    set (isShared) {
      self._isShared = isShared
    }
  }
  
  override var treeType: TreeType {
    return TreeType.GDRIVE
  }
  
  override var isLive: Bool {
    return self.googID != nil
  }
  
  init(_ nodeIdentifer: GDriveIdentifier, _ parentList: [UID] = [], trashed: TrashStatus, googID: GoogID?, createTS: UInt64?,
       modifyTS: UInt64?, name: String, ownerUID: UID, driveID: String?, isShared: Bool, sharedByUserUID: UID?, syncTS: UInt64?) {
    self.googID = googID
    self.createTS = createTS
    self._modifyTS = modifyTS
    self._name = name
    self.ownerUID = ownerUID
    self.driveID = driveID
    self._isShared = isShared
    self.sharedByUserUID = sharedByUserUID
    self._syncTS = syncTS
    
    super.init(nodeIdentifer, parentList, trashed)
  }
  
  override func updateFrom(_ otherNode: Node) {
    if let otherGDriveNode = otherNode as? GDriveNode {
      self.googID = otherGDriveNode.googID
      self.createTS = otherGDriveNode.createTS
      self._modifyTS = otherGDriveNode._modifyTS
      self.ownerUID = otherGDriveNode.ownerUID
      self.driveID = otherGDriveNode.driveID
      self._isShared = otherGDriveNode.isShared
      self.sharedByUserUID = otherGDriveNode.sharedByUserUID
      self._syncTS = otherGDriveNode._syncTS
    } else {
      // TODO: error
    }
    
    super.updateFrom(otherNode)
  }
  
}
