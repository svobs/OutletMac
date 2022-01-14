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

  override var description: String {
    return "ContainerNode(\(nodeIdentifier.description) parents=\(parentList) trashed=\(trashed) icon=\(icon) name='\(name)'"
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
  init(_ nodeIdentifer: ChangeTreeSPID) {
    assert(type(of: nodeIdentifer) == ChangeTreeSPID.self)
    super.init(nodeIdentifer)
  }
  
  override var name: String {
    get {
      return (nodeIdentifier as? ChangeTreeSPID)?.category.display() ?? "[ERROR_CN01]"
    }
  }

  var category: ChangeTreeCategory {
    return (nodeIdentifier as? ChangeTreeSPID)!.category
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

  override var description: String {
    return "CategoryNode(\(nodeIdentifier.description) parents=\(parentList) trashed=\(trashed) icon=\(icon) category=\(category) name='\(name)'"
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
        return .ICON_LOCAL_DISK_MACOS
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

  override var description: String {
    return "RootTypeNode(\(nodeIdentifier.description) parents=\(parentList) trashed=\(trashed) icon=\(icon) name='\(name)'"
  }
}
