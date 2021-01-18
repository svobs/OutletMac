//
//  Node.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-15.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class Node {
  var nodeIdentifier: NodeIdentifier
  var parentList: [UID]
  var trashed: TrashStatus
  var _icon: IconId?
  
  var isFile: Bool {
    false
  }
  
  var isDir: Bool {
    false
  }
  
  var isDisplayOnly: Bool {
    false
  }
  
  var isLive: Bool {
    false
  }
  
  var isEphemeral: Bool {
    false
  }
  
  var hasTuple: Bool {
    false
  }
  
  var isShared: Bool {
    false
  }
  
  var name: String {
    return URL(fileURLWithPath: self.nodeIdentifier.pathList[0]).lastPathComponent
  }
  
  var etc: String {
    return ""
  }
  
  var md5: MD5? {
    return nil
  }
  
  var sha256: SHA256? {
    return nil
  }
  
  var sizeBytes: UInt64? {
    return nil
  }
  
  var syncTS: UInt64? {
    return nil
  }
  
  var modifyTS: UInt64? {
    return nil
  }
  
  var changeTS: UInt64? {
    return nil
  }
  
  var uid: UID {
    return self.nodeIdentifier.uid
  }
  
  var defaultIcon: IconId {
    if self.isLive {
      return .ICON_GENERIC_FILE
    } else {
      return .ICON_FILE_CP_DST
    }
  }
  
  var icon: IconId {
    return self._icon ?? self.defaultIcon
  }
  
  init(_ nodeIdentifer: NodeIdentifier, _ parentList: [UID] = [], _ trashed: TrashStatus = .NOT_TRASHED) {
    self.nodeIdentifier = nodeIdentifer
    self.parentList = parentList
    self.trashed = trashed
    self._icon = nil
  }
  
  func getTreeType() -> TreeType {
    return self.nodeIdentifier.getTreeType()
  }
  
  func getTag() -> String {
    return "\(nodeIdentifier)"
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
