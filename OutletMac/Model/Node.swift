//
//  Node.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-15.
//

import Foundation

class Node: CustomStringConvertible {
  var nodeIdentifier: NodeIdentifier
  var parentList: [UID]
  var trashed: TrashStatus
  var _icon: IconID?
  
  public var description: String {
    return "Node(\(nodeIdentifier.description) parents=\(parentList) trashed=\(trashed) icon=\(icon)"
  }
  
  var isFile: Bool {
    get {
      false
    }
  }
  
  var isDir: Bool {
    get {
      false
    }
  }

  /**
   Returns true if this node does not correspond to a particular path in a filesystem (e.g. a CategoryNode)
   */
  var isDisplayOnly: Bool {
    get {
      false
    }
  }
  
  var isContainerNode: Bool {
    get {
      false
    }
  }
  
  var isLive: Bool {
    get {
      false
    }
  }
  
  var isEphemeral: Bool {
    get {
      false
    }
  }
  
  var isShared: Bool {
    get {
      false
    }
  }
  
  var name: String {
    get {
      assert (self.nodeIdentifier.pathList.count > 0, "Node has no paths: \(nodeIdentifier)")
      return URL(fileURLWithPath: self.nodeIdentifier.pathList[0]).lastPathComponent
    }
  }
  
  var etc: String {
    get {
      self.getDirStats()?.etc ?? ""
    }
  }
  
  var summary: String {
    get {
      return self.getDirStats()?.summary ?? ""
    }
  }
  
  var md5: MD5? {
    get {
      return nil
    }
  }
  
  var sha256: SHA256? {
    get {
      return nil
    }
  }
  
  var sizeBytes: UInt64? {
    get {
      return self.getDirStats()?.sizeBytes
    }
  }
  
  var syncTS: UInt64? {
    get {
      return nil
    }
  }

  var createTS: UInt64? {
    get {
      return nil
    }
  }

  var modifyTS: UInt64? {
    get {
      return nil
    }
  }
  
  var changeTS: UInt64? {
    get {
      return nil
    }
  }
  
  var uid: UID {
    get {
      return self.nodeIdentifier.nodeUID
    }
  }
  
  var defaultIcon: IconID {
    get {
      if self.isLive {
        return .ICON_GENERIC_FILE
      } else {
        return .ICON_FILE_CP_DST
      }
    }
  }
  
  var icon: IconID {
    get {
      if self._icon == nil || self._icon == IconID.NONE {
        return self.defaultIcon
      } else {
        return self._icon!
      }
    }
  }
  
  var customIcon: IconID? {
    get {
      return self._icon
    }
    set (customIcon) {
      self._icon = customIcon
    }
  }
  
  var treeType: TreeType {
    get {
      return self.nodeIdentifier.treeType
    }
  }

  var deviceUID: UID {
    get {
      return self.nodeIdentifier.deviceUID
    }
  }
  
  var tag: String {
    get {
      return "\(nodeIdentifier)"
    }
  }

  /** Convenience getter for all paths */
  var pathList: [String] {
    get {
      return self.nodeIdentifier.pathList
    }
  }

  /** Convenience getter for the first path in the path list */
  var firstPath: String {
    get {
      assert(self.nodeIdentifier.pathList.count > 0, "Expected node to have at least 1 path: \(self.description)")
      return self.nodeIdentifier.pathList[0]
    }
  }

  func isParentOf(_ otherNode: Node) -> Bool {
    fatalError("Cannot call isParentOf for Node base class!")
  }

  /** Use isDir to check if node has DirStats */
  func setDirStats(_ dirStats: DirectoryStats?) {
    preconditionFailure("setDirStats(): class does not implement setDirStats(): \(type(of: self))!")
  }
  
  func getDirStats() -> DirectoryStats? {
    nil
  }
  
  init(_ nodeIdentifer: NodeIdentifier, _ parentList: [UID] = [], _ trashed: TrashStatus = .NOT_TRASHED) {
    self.nodeIdentifier = nodeIdentifer
    self.parentList = parentList
    self.trashed = trashed
    self._icon = nil
  }
  
  func updateFrom(_ otherNode: Node) {
    self.parentList = otherNode.parentList
    self.nodeIdentifier.pathList = otherNode.nodeIdentifier.pathList
    self.trashed = otherNode.trashed
  }
  
  func getSingleParent() throws -> UID {
    if self.parentList.count != 1 {
      throw OutletError.invalidState("Node.getSingleParent(): expected exactly 1 parent but found \(self.parentList.count) (UID=\(self.uid)))")
    }
    return self.parentList[0]
  }
}

// the only time node is nil is if the tree's root does not exist
typealias SPIDNodePair = (spid: SinglePathNodeIdentifier, node: Node)


/**
 CLASS DirectoryStats
 Encapsulates stats for a directory node
 */
class DirectoryStats : CustomStringConvertible {
  var fileCount: UInt32 = 0
  var trashedFileCount: UInt32 = 0
  var dirCount: UInt32 = 0
  var trashedDirCount: UInt32 = 0
  var trashedBytes: UInt64 = 0
  var sizeBytes: UInt64 = 0
  
  func clear() {
    self.fileCount = 0
    self.trashedFileCount = 0
    self.dirCount = 0
    self.trashedDirCount = 0
    self.trashedBytes = 0
    self.sizeBytes = 0
  }
  
  var etc: String {
    get {
      let files = self.fileCount + self.trashedFileCount
      let dirs = self.dirCount + self.trashedDirCount

      let multi = files == 1 ? "" : "s"
      let filesString = "\(StringUtil.formatNumberWithCommas(files)) file\(multi)"
      
      var dirsString: String = ""
      if dirs > 0 {
        let multi = dirs == 1 ? "" : "s"
        dirsString = ", \(StringUtil.formatNumberWithCommas(dirs)) dir\(multi)"
      }
      
      return "\(filesString)\(dirsString)"
    }
  }
  
  var summary: String {
    if self.sizeBytes == 0 && self.fileCount == 0 {
      return ""
    }
    let size: String = StringUtil.formatByteCount(sizeBytes)
    let dirsString = self.dirCount == 0 ? "" : " and \(StringUtil.formatNumberWithCommas(self.dirCount)) dirs"
    return "\(size) in \(StringUtil.formatNumberWithCommas(self.fileCount)) files\(dirsString)"
  }

  var description: String {
    get {
      "DirStats(reg=[\(fileCount)f \(dirCount)d \(sizeBytes)b] trash=[\(trashedFileCount)f \(trashedDirCount)d \(trashedBytes)b])"
    }
  }
}

/**
 CLASS EphemeralNode
 Not a "real" node in the sense that it represents something from central, but needed to display something to the user
 */
class EphemeralNode: Node {
  private let _name: String
  init(_ name: String, parent: SPID, _ iconID: IconID) {
    self._name = name
    super.init(EphemeralNodeIdentifier(parent: parent), [], .NOT_TRASHED)
    self._icon = iconID
  }

  override var name: String {
    get {
      return self._name
    }
  }

  override var isEphemeral: Bool {
    get {
      return true
    }
  }

  override func isParentOf(_ otherNode: Node) -> Bool {
    return false
  }

  override var isDisplayOnly: Bool {
    get {
      true
    }
  }

  func toSN() -> SPIDNodePair {
    return (self.nodeIdentifier as! SPID, self)
  }

  override var description: String {
    return "EphemeralNode(\(nodeIdentifier.description) parents=\(parentList) icon=\(icon) name='\(name)'"
  }
}

class DirNode: Node {
  // need to include this for all nodes where isDir==true
  var _dirStats: DirectoryStats? = nil
  init(_ nodeIdentifer: NodeIdentifier) {
    super.init(nodeIdentifer)
  }

  override var isDir: Bool {
    get {
      return true
    }
  }

  override func setDirStats(_ dirStats: DirectoryStats?) {
    self._dirStats = dirStats
  }

  override func getDirStats() -> DirectoryStats? {
    return self._dirStats
  }

  override var description: String {
    return "DirNode(\(nodeIdentifier.description) parents=\(parentList) trashed=\(trashed) icon=\(icon) name='\(name)'"
  }
}

/**
  Represents a directory which does not exist. Use this in SPIDNodePair objects when the SPID points to something which doesn't exist.
  It's much safer to use this class rather than remembering to deal with null/nil/None.
 */
class NonexistentDirNode: DirNode {
  let _name: String

  init(_ nodeIdentifer: NodeIdentifier, _ name: String) {
    self._name = name
    super.init(nodeIdentifer)
  }

  override var name: String {
    get {
      return self._name
    }
  }

  override func updateFrom(_ otherNode: Node) {
    self.parentList = otherNode.parentList
    self.nodeIdentifier.pathList = otherNode.nodeIdentifier.pathList
    self.trashed = otherNode.trashed
  }

  override func isParentOf(_ otherNode: Node) -> Bool {
    return false
  }

}
