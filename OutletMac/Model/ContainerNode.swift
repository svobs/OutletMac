//
//  ContainerNode.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-24.
//

/**
 CLASS ContainerNode
 */
class ContainerNode: DirNode {

  override public var description: String {
    return "ContainerNode(\(nodeIdentifier.description) parents=\(parentList) trashed=\(trashed)"
  }

  override var isContainerNode: Bool {
    get {
      true
    }
  }
}

/**
 CLASS CategoryNode
 */
class CategoryNode: ContainerNode {
  var opType: UserOpType
  
  init(_ nodeIdentifer: NodeIdentifier, _ opType: UserOpType) {
    self.opType = opType
    super.init(nodeIdentifer)
  }
  
  override var name: String {
    get {
      return UserOpType.DISPLAYED_USER_OP_TYPES[self.opType]!
    }
  }
  
  override var defaultIcon: IconID {
    get {
      return .ICON_GENERIC_DIR
    }
  }

  override var isDisplayOnly: Bool {
    get {
      true
    }
  }

  override func isParentOf(_ otherNode: Node) -> Bool {
    return false
  }
}

/**
 CLASS RootTypeNode
 */
class RootTypeNode: ContainerNode {
  
  override var name: String {
    get {
      return self.treeType.getName()
    }
  }
  
  override var tag: String {
    get {
      return self.name
    }
  }
  
  override var defaultIcon: IconID {
    get {
      if self.treeType == .LOCAL_DISK {
        return .ICON_LOCAL_DISK_LINUX
      } else if self.treeType == .GDRIVE {
        return .ICON_GDRIVE
      }
      return .ICON_GENERIC_DIR
    }
  }

  override var isDisplayOnly: Bool {
    get {
      true
    }
  }
}
