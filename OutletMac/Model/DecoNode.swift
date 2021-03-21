//
//  DecoNode.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-24.
//

class DecoNode : Node {
  let delegate: Node
  
  init(_ uid: UID, _ parentUID: UID, _ delegateNode: Node) {
    let nodeIdentifier: NodeIdentifier = delegateNode.nodeIdentifier.copy(with: uid)
    self.delegate = delegateNode
    super.init(nodeIdentifier, [parentUID], delegateNode.trashed)
  }
  
  override func updateFrom(_ otherNode: Node) {
    self.delegate.updateFrom(otherNode)
  }
  
  override var trashed: TrashStatus {
    get {
      return self.delegate.trashed
    }
    set (trashed) {
      self.delegate.trashed = trashed
    }
  }
  
  override var isFile: Bool {
    get {
      return self.delegate.isFile
    }
  }
  
  override var isDir: Bool {
    get {
      return self.delegate.isDir
    }
  }
  
  override var isDisplayOnly: Bool {
    get {
      return self.delegate.isDisplayOnly
    }
  }
  
  override var isDecorator: Bool {
    get {
      true
    }
  }
  
  override var isLive: Bool {
    get {
      return self.delegate.isLive
    }
  }
  
  override var isEphemeral: Bool {
    get {
      return self.delegate.isEphemeral
    }
  }
  
  override var isShared: Bool {
    get {
      return self.delegate.isShared
    }
  }
  
  override var name: String {
    get {
      return self.delegate.name
    }
  }
  
  override var etc: String {
    get {
      return self.delegate.etc
    }
  }
  
  override var summary: String {
    get {
      return self.delegate.summary
    }
  }
  
  override var md5: MD5? {
    get {
      return self.delegate.md5
    }
  }
  
  override var sha256: MD5? {
    get {
      return self.delegate.sha256
    }
  }
  
  override var sizeBytes: UInt64? {
    get {
      return self.delegate.sizeBytes
    }
  }
  
  override var syncTS: UInt64? {
    get {
      return self.delegate.syncTS
    }
  }
  
  override var modifyTS: UInt64? {
    get {
      return self.delegate.modifyTS
    }
  }
  
  override var icon: IconID {
    get {
      return self.delegate.icon
    }
    set (icon) {
      self.delegate.customIcon = icon
    }
  }
}

/**
 CLASS DecoDirNode
 */
class DecoDirNode : DecoNode {
  var _dirStats: DirectoryStats? = nil
  
  override var etc: String {
    get {
      if self._dirStats == nil {
        return ""
      } else {
        return self._dirStats!.etc
      }
    }
  }
  
  override var summary: String {
    get {
      if self._dirStats == nil {
        return ""
      } else {
        return self._dirStats!.summary
      }
    }
  }
  
  override var sizeBytes: UInt64? {
    get {
      self._dirStats!.sizeBytes
    }
    set (sizeBytes) {
      if self._dirStats == nil {
        self._dirStats = DirectoryStats()
      }
      self._dirStats!.sizeBytes = sizeBytes!
    }
  }
  
  func zeroOutStats() {
    if (self._dirStats != nil) {
      self._dirStats!.clear()
    }
  }
  
  func isStatsLoaded() -> Bool {
    return self._dirStats != nil
  }
  
  override func setDirStats(_ dirStats: DirectoryStats?) {
    self._dirStats = dirStats
  }
}

/**
 CLASS DecoratorFactory
 */
class DecoratorFactory {
  static func decorate(_ node: Node, _ decoratorUID: UID, _ decoratorParentUID: UID) -> DecoNode {
    assert(!node.isDecorator, "Cannot decorate a decorated node!")
    if node.isDir {
      return DecoDirNode(decoratorUID, decoratorParentUID, node)
    } else {
      return DecoNode(decoratorUID, decoratorParentUID, node)
    }
  }
}
