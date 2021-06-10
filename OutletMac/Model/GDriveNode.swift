//
//  GDriveNode.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-20.
//

import Foundation

typealias GoogID = String

/**
 CLASS GDriveNode
 
 "Abstract" base class: do not instantiate directly
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
  
  var mimeTypeUID: UID {
    get {
      return NULL_UID
    }
  }
  
  var ownerUID: UID
  
  /**
   This will only ever contain other users' drive_ids.
   */
  var driveID: String?
  
  var sharedByUserUID: UID?
  
  /**
   If true, item is shared by shared_by_user_uid
   */
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
      assert(false)
    }
    
    super.updateFrom(otherNode)
  }
}

/**
 CLASS GDriveFolder
 */
class GDriveFolder: GDriveNode {
  var isAllChildrenFetched: Bool
  var _dirStats: DirectoryStats?
  init(_ nodeIdentifer: GDriveIdentifier, _ parentList: [UID] = [], trashed: TrashStatus, googID: GoogID?, createTS: UInt64?, modifyTS: UInt64?,
       name: String, ownerUID: UID, driveID: String?, isShared: Bool, sharedByUserUID: UID?, syncTS: UInt64?, allChildrenFetched: Bool) {
    self.isAllChildrenFetched = allChildrenFetched
    
    super.init(nodeIdentifer, parentList, trashed: trashed, googID: googID, createTS: createTS, modifyTS: modifyTS, name: name,
               ownerUID: ownerUID, driveID: driveID, isShared: isShared, sharedByUserUID: sharedByUserUID, syncTS: syncTS)
  }
  
  override var mimeTypeUID: UID {
    get {
      return GDRIVE_FOLDER_MIME_TYPE_UID
    }
  }
  
  override func updateFrom(_ otherNode: Node) {
    if let otherGDriveFolder = otherNode as? GDriveFolder {
      self.isAllChildrenFetched = otherGDriveFolder.isAllChildrenFetched
    } else {
      assert(false)
    }
    
    super.updateFrom(otherNode)
  }
  
  override var isDir: Bool {
    get {
      true
    }
  }
  
  override var defaultIcon: IconID {
    get {
      if self.trashed == .NOT_TRASHED {
        if self.isLive {
          return .ICON_GENERIC_DIR
        } else {
          return .ICON_DIR_MK
        }
      }
      return .ICON_DIR_TRASHED
    }
  }

  override var sizeBytes: UInt64? {
    get {
      return self._dirStats?.sizeBytes
    }
  }

  override var etc: String {
    get {
      return self._dirStats?.etc ?? ""
    }
  }
  
  override var summary: String {
    get {
      if self._dirStats == nil {
        return "0 items"
      } else {
        return self._dirStats!.summary
      }
    }
  }
  
  override func setDirStats(_ dirStats: DirectoryStats?) {
    self._dirStats = dirStats
  }

  override func getDirStats() -> DirectoryStats? {
    return self._dirStats
  }
  
  override public var description: String {
    return "GDriveFolder(\(nodeIdentifier.description) googID=\(googID ?? "null") parents=\(parentList) name=\(name) trashed=\(trashed) " +
      "ownerUID=\(ownerUID) driveID=\(driveID ?? "null") isShared=\(isShared) sharedByUserUID=\(sharedByUserUID ?? 0) syncTS=\(syncTS ?? 0) " +
      "allChildrenFetched=\(isAllChildrenFetched))"
  }

  override func isParentOf(_ potentialChildNode: Node) -> Bool {
    return potentialChildNode.deviceUID == self.deviceUID && potentialChildNode.parentList.contains(self.uid)
  }

  // TODO: override equals
  
}

/**
 CLASS GDriveFile
 */
class GDriveFile: GDriveNode {
  var version: UInt32?
  var _md5: MD5?
  override var md5: MD5? {
    get {
      return _md5
    }
    set (md5) {
      self._md5 = md5
    }
  }
  
  var _mimeTypeUID: UID
  override var mimeTypeUID: UID {
    get {
      return _mimeTypeUID
    }
    set (mimeTypeUID) {
      self._mimeTypeUID = mimeTypeUID
    }
  }
  
  var _sizeBytes: UInt64?
  override var sizeBytes: UInt64? {
    get {
      return _sizeBytes
    }
    set (sizeBytes) {
      self._sizeBytes = sizeBytes
    }
  }
  
  init(_ nodeIdentifer: GDriveIdentifier, _ parentList: [UID] = [], trashed: TrashStatus, googID: GoogID?, createTS: UInt64?, modifyTS: UInt64?,
       name: String, ownerUID: UID, driveID: String?, isShared: Bool, sharedByUserUID: UID?, syncTS: UInt64?, version: UInt32?, md5: MD5?,
       mimeTypeUID: UID, sizeBytes: UInt64?) {
    self.version = version
    self._md5 = md5
    self._mimeTypeUID = mimeTypeUID
    self._sizeBytes = sizeBytes
    
    super.init(nodeIdentifer, parentList, trashed: trashed, googID: googID, createTS: createTS, modifyTS: modifyTS, name: name, ownerUID: ownerUID,
               driveID: driveID, isShared: isShared, sharedByUserUID: sharedByUserUID, syncTS: syncTS)
  }
  
  override func updateFrom(_ otherNode: Node) {
    if let otherGDriveFile = otherNode as? GDriveFile {
      self.version = otherGDriveFile.version
      self.md5 = otherGDriveFile.md5
      self.mimeTypeUID = otherGDriveFile.mimeTypeUID
      self.sizeBytes = otherGDriveFile.sizeBytes
    } else {
      assert(false)
    }
    
    super.updateFrom(otherNode)
  }
  
  override var isFile: Bool {
    get {
      true
    }
  }
  
  override var defaultIcon: IconID {
    get {
      if self.trashed == .NOT_TRASHED {
        if self.isLive {
          return .ICON_GENERIC_FILE
        } else {
          return .ICON_FILE_CP_DST
        }
      }
      return .ICON_FILE_TRASHED
    }
  }
  
  override public var description: String {
    let sizeStr: String = sizeBytes == nil ? "null" : String(sizeBytes!)
    let createTSStr: String = createTS == nil ? "null" : String(createTS!)
    let modifyTSStr: String = modifyTS == nil ? "null" : String(modifyTS!)
    let sharedByUserUIDStr: String = sharedByUserUID == nil ? "null" : String(sharedByUserUID!)
    let syncTSStr: String = syncTS == nil ? "null" : String(syncTS!)
    return "GDriveFile(\(nodeIdentifier.description) googID=\(googID ?? "null") parents=\(parentList) name=\(name) MD5=\(md5 ?? "null") " +
      "mimeTypeUID=\(mimeTypeUID) size=\(sizeStr) trashed=\(trashed) createTS=\(createTSStr) modifyTS=\(modifyTSStr) " +
      "ownerUID=\(ownerUID) driveID=\(driveID ?? "null") isShared=\(isShared) sharedByUserUID=\(sharedByUserUIDStr) syncTS=\(syncTSStr))"
  }

  override func isParentOf(_ otherNode: Node) -> Bool {
    // A file can never be parent of anything (awww...)
    return false
  }
}
