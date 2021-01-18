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


//protocol HasChildStats {
//  var fileCount: UInt { get set }
//  var trashedFileCount: UInt { get set }
//
//  var dirCount: UInt { get set }
//  var trashedDirCount: UInt { get set }
//
//  var sizeBytes: UInt { get set }
//  var trashedBytes: UInt { get set }
//
//}
//
//extension HasChildStats {
//  func updateFrom(_ other: HasChildStats) {
//    self.fileCount = other.fileCount
//  }
//}
