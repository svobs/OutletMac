//
//  LocalNode.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-18.
//

import Foundation

/**
 CLASS LocalNode
 */
class LocalNode: Node {
  var _isLive: Bool
  override var isLive: Bool {
    _isLive
  }
  
  init(_ nodeIdentifer: NodeIdentifier, _ parentUID: UID, _ trashed: TrashStatus = .NOT_TRASHED, isLive: Bool,
       syncTS: UInt64?, createTS: UInt64?, modifyTS: UInt64?, changeTS: UInt64?) {
    self._isLive = isLive
    super.init(nodeIdentifer, [parentUID], trashed)
  }
  
  override func updateFrom(_ otherNode: Node) {
    super.updateFrom(otherNode)
    self._isLive = otherNode.isLive
  }
  
  func deriveParentPath() throws -> String {
    return URL(fileURLWithPath: self.nodeIdentifier.getSinglePath()).deletingLastPathComponent().absoluteString
  }
  
  override func getSingleParent() -> UID {
    return self.parentList[0]
  }

  var _syncTS: UInt64?
  override var syncTS: UInt64? {
    get {
      return self._syncTS
    }
    set(newSyncTS) {
      self._syncTS = newSyncTS
    }
  }

  var _createTS: UInt64?
  override var createTS: UInt64? {
    get {
      return self._createTS
    }
    set(createTS) {
      self._createTS = createTS
    }
  }

  var _modifyTS: UInt64?
  override var modifyTS: UInt64? {
    get {
      return self._modifyTS
    }
    set(modifyTS) {
      self._modifyTS = modifyTS
    }
  }

  var _changeTS: UInt64?
  override var changeTS: UInt64? {
    get {
      return self._changeTS
    }
    set(changeTS) {
      self._changeTS = changeTS
    }
  }

}

/**
 CLASS LocalDirNode
 */
class LocalDirNode: LocalNode {
  var _dirStats: DirectoryStats? = nil
  
  override var isDir: Bool {
    get {
      true
    }
  }

  override func setDirStats(_ dirStats: DirectoryStats?) {
    self._dirStats = dirStats
  }

  override func getDirStats() -> DirectoryStats? {
    return self._dirStats
  }

  override var defaultIcon: IconID {
    get {
      return .ICON_GENERIC_DIR
    }
  }
  
  override public var description: String {
    return "LocalDirNode(\(nodeIdentifier.description) parents=\(parentList) sizeBytes=\(self.sizeBytes ?? 0) createTS=\(createTS ?? 0) modifyTS=\(modifyTS ?? 0) changeTS=\(changeTS ?? 0) trashed=\(self.trashed) live=\(self._isLive) icon=\(icon)"
  }


  override func isParentOf(_ potentialChildNode: Node) -> Bool {
    if potentialChildNode.deviceUID == self.deviceUID {
      let potentialChildNodeURL: URL = URL(fileURLWithPath: potentialChildNode.firstPath)
      if potentialChildNodeURL.deletingLastPathComponent() == URL(fileURLWithPath: self.firstPath) {
        return true
      }
    }
    // A file can never be the parent of anything
    return false
  }
}

/**
 CLASS LocalFileNode
 */
class LocaFileNode: LocalNode {
  var _md5: MD5?
  override var md5: MD5? {
    get {
      return self._md5
    }
    set(md5) {
      self._md5 = md5
    }
  }
  
  var _sha256: SHA256?
  override var sha256: SHA256? {
    get {
      return self._sha256
    }
    set(sha256) {
      self._sha256 = sha256
    }
  }
  
  var _sizeBytes: UInt64?
  override var sizeBytes: UInt64? {
    get {
      return self._sizeBytes
    }
    set(sizeBytes) {
      self._sizeBytes = sizeBytes
    }
  }

  override var isFile: Bool {
    get {
      true
    }
  }
  
  override public var description: String {
    return "LocalFileNode(\(nodeIdentifier.description) parents=\(parentList) md5=\(md5 ?? "null") sha256=\(sha256 ?? "null") sizeBytes=\(sizeBytes ?? 0) createTS=\(createTS ?? 0) modifyTS=\(modifyTS ?? 0) changeTS=\(changeTS ?? 0) trashed=\(trashed) live=\(_isLive) icon=\(icon)"
  }
  
  init(_ nodeIdentifer: NodeIdentifier, _ parentUID: UID, trashed: TrashStatus = .NOT_TRASHED, isLive: Bool, md5: MD5? = nil, sha256: SHA256? = nil,
       sizeBytes: UInt64?, syncTS: UInt64?, createTS: UInt64?, modifyTS: UInt64?, changeTS: UInt64?) {
    self._md5 = md5
    self._sha256 = sha256
    self._sizeBytes = sizeBytes
    super.init(nodeIdentifer, parentUID, trashed, isLive: isLive, syncTS: syncTS, createTS: createTS, modifyTS: modifyTS, changeTS: changeTS)
  }

  override func isParentOf(_ otherNode: Node) -> Bool {
    // A file can never be the parent of anything
    return false
  }
}
