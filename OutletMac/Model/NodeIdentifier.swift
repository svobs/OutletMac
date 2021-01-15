//
//  NodeIdentifier.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-14.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

enum TreeType: UInt {
  case NA = 0
  case MIXED = 1
  case LOCAL_DISK = 2
  case GDRIVE = 3
  
  static func display(code: UInt) -> String {
      guard let treeType = TreeType(rawValue: code) else {
          return "UNKNOWN"
      }

      switch treeType {
      case .NA:
          return "✪"
      case .MIXED:
          return "M"
      case .LOCAL_DISK:
          return "L"
      case .GDRIVE:
          return "G"
      }
  }
}

enum TreeDisplayMode: Int {
  case ONE_TREE_ALL_ITEMS = 1
  case CHANGES_ONE_TREE_PER_CATEGORY = 2
}

class NodeIdentifier {
  let uid: UID
  // TODO: when I get better with Swift, pursue union type
  let pathList: [String]
  
  init(_ uid: UID, _ pathList: [String]) {
    self.uid = uid
    self.pathList = pathList
  }
  
  func getTreeType() -> TreeType {
    return .NA
  }
  
  // MARK: SPID
  
  func isSpid() -> Bool {
    false
  }
  
  func isSinglePath() throws -> Bool {
    throw OutletError.invalidOperation
  }
  
  func getSinglePath() throws -> String {
    throw OutletError.invalidOperation
  }
  
}

class NullNodeIdentifier: NodeIdentifier {
  init() {
    super.init(NULL_UID, [])
  }
}

class SinglePathNodeIdentifier: NodeIdentifier {
  let treeType: TreeType
  init(_ uid: UID, _ singlePath: String, _ treeType: TreeType) {
    self.treeType = treeType
    super.init(uid, [singlePath])
  }
  
  override func getTreeType() -> TreeType {
    return self.treeType
  }
  
  override func isSpid() -> Bool {
    false
  }
  
  override func isSinglePath() throws -> Bool {
    return true
  }
  
  override func getSinglePath() -> String {
    self.pathList[0]
  }
}

typealias SPID = SinglePathNodeIdentifier


class GDriveIdentifier: NodeIdentifier {
  let treeType: TreeType
  init(_ uid: UID, _ pathList: [String], _ treeType: TreeType) {
    self.treeType = treeType
    super.init(uid, pathList)
  }
  
  override func getTreeType() -> TreeType {
    return self.treeType
  }
}

class LocalNodeIdentifier: SinglePathNodeIdentifier {
  override init(_ uid: UID, _ singlePath: String, _ treeType: TreeType) {
    super.init(uid, singlePath, .LOCAL_DISK)
  }
  
}
