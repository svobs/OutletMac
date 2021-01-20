//
//  LocalNode.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-18.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class LocalNode: Node {
  var _isLive: Bool
  override var isLive: Bool {
    _isLive
  }
  
  init(_ nodeIdentifer: NodeIdentifier, _ parentUID: UID, _ trashed: TrashStatus = .NOT_TRASHED, isLive: Bool) {
    self._isLive = isLive
    super.init(nodeIdentifer, [parentUID], trashed)
  }
  
  override func updateFrom(_ otherNode: Node) {
    super.updateFrom(otherNode)
    self._isLive = otherNode.isLive
  }
  
  func deriveParentPath() throws -> String {
    return URL(fileURLWithPath: try self.nodeIdentifier.getSinglePath()).deletingLastPathComponent().absoluteString
  }
  
  func getSingleParent() -> UID {
    return self.parentList[0]
  }
}

class LocaFilelNode: LocalNode {
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
  
  var _syncTS: UInt64?
  override var syncTS: UInt64? {
    get {
      return self._syncTS
    }
    set(newSyncTS) {
      self._syncTS = newSyncTS
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
  
  override var isFile: Bool {
    get {
      true
    }
  }
  
  override public var description: String {
    return "LocalFileNode(\(nodeIdentifier.description) parents=\(parentList) md5=\(md5 ?? "null") sha256=\(self.sha256 ?? "null") sizeBytes=\(self.sizeBytes ?? 0) trashed=\(self.trashed)"
  }
  
  init(_ nodeIdentifer: NodeIdentifier, _ parentUID: UID, trashed: TrashStatus = .NOT_TRASHED, isLive: Bool, md5: MD5? = nil, sha256: SHA256? = nil,
                sizeBytes: UInt64?, syncTS: UInt64?, modifyTS: UInt64?, changeTS: UInt64?) {
    self._md5 = md5
    self._sha256 = sha256
    self._sizeBytes = sizeBytes
    self._syncTS = syncTS
    self._modifyTS = modifyTS
    self._changeTS = changeTS
    super.init(nodeIdentifer, parentUID, trashed, isLive: isLive)
  }
}

class LocalDirNode: LocalNode {
  var _childStats: ChildStats? = nil
  
  // TODO: HasChildStats
  override var isDir: Bool {
    get {
      true
    }
  }
  
  override var defaultIcon: IconId {
    get {
      return .ICON_GENERIC_DIR
    }
  }
  
  override public var description: String {
    return "LocalDirNode(\(nodeIdentifier.description) parents=\(parentList) sizeBytes=\(self.sizeBytes ?? 0) trashed=\(self.trashed)"
  }
  
  override var etc: String {
    get {
      ""
    }
  }
  
  override var sizeBytes: UInt64? {
    get {
      self._childStats!.sizeBytes
    }
    set (sizeBytes) {
      if self._childStats == nil {
        self._childStats = ChildStats()
      }
      self._childStats!.sizeBytes = sizeBytes!
    }
  }
  
  func zeroOutStats() {
    if (self._childStats != nil) {
      self._childStats!.clear()
    }
  }
  
  func isStatsLoaded() -> Bool {
    return self._childStats != nil
  }
}

