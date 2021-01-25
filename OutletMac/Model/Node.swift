//
//  Node.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-15.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class Node: CustomStringConvertible {
  var nodeIdentifier: NodeIdentifier
  var parentList: [UID]
  var trashed: TrashStatus
  var _icon: IconId?
  
  public var description: String {
    return "Node(\(nodeIdentifier.description) parents=\(parentList) trashed=\(trashed)"
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
  
  var isDisplayOnly: Bool {
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
  
  var hasTuple: Bool {
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
      return URL(fileURLWithPath: self.nodeIdentifier.pathList[0]).lastPathComponent
    }
  }
  
  var etc: String {
    get {
      ""
    }
  }
  
  var summary: String {
    get {
      ""
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
      return nil
    }
  }
  
  var syncTS: UInt64? {
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
      return self.nodeIdentifier.uid
    }
  }
  
  var defaultIcon: IconId {
    get {
      if self.isLive {
        return .ICON_GENERIC_FILE
      } else {
        return .ICON_FILE_CP_DST
      }
    }
  }
  
  var icon: IconId {
    get {
      return self._icon ?? self.defaultIcon
    }
    set (icon) {
      self._icon = icon
    }
  }
  
  var treeType: TreeType {
    get {
      return self.nodeIdentifier.getTreeType()
    }
  }
  
  var tag: String {
    get {
      return "\(nodeIdentifier)"
    }
  }
  
  init(_ nodeIdentifer: NodeIdentifier, _ parentList: [UID] = [], _ trashed: TrashStatus = .NOT_TRASHED) {
    self.nodeIdentifier = nodeIdentifer
    self.parentList = parentList
    self.trashed = trashed
    self._icon = nil
  }
  
  func toTuple() throws {
    throw OutletError.invalidOperation
  }
  
  func updateFrom(_ otherNode: Node) {
    self.parentList = otherNode.parentList
    self.nodeIdentifier.pathList = otherNode.nodeIdentifier.pathList
    self.trashed = otherNode.trashed
  }
}

typealias SPIDNodePair = (spid: SinglePathNodeIdentifier, node: Node)


/**
 CLASS DirectoryStats
 Encapsulates stats for a directory node
 */
class DirectoryStats {
  var fileCount: UInt64 = 0
  var trashedFileCount: UInt64 = 0
  var dirCount: UInt64 = 0
  var trashedDirCount: UInt64 = 0
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
      
      var filesString: String = ""
      let multi = files == 1 ? "" : "s"
      filesString = "\(files) file\(multi)"
      
      var dirsString: String = ""
      if dirs > 0 {
        let multi = dirs == 1 ? "" : "s"
        dirsString = "\(dirs) file\(multi)"
      }
      
      return "\(filesString), \(dirsString)"
    }
  }
  
  var summary: String {
    if self.sizeBytes == 0 && self.fileCount == 0 {
      return ""
    }
    let size: String = String(sizeBytes)  // TODO: formatting!
    return "\(size) in \(self.fileCount) files and \(self.dirCount) dirs"  // TODO: formatting with commas, similar to Python's :n
  }
  
}
