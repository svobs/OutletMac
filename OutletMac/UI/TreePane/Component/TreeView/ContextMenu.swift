//
//  ContextMenu.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/17.
//

import SwiftUI

class MenuItemWithSNList: NSMenuItem {
  var snList: [SPIDNodePair] = []
}

class MenuItemWithNodeList: NSMenuItem {
  var nodeList: [Node] = []
}


class TreeContextMenu {
  weak var con: TreePanelControllable! = nil  // Need to set this in parent controller's start() method

  var treeID: String {
    return con.treeID
  }

  public func rebuildMenuFor(_ menu: NSMenu, _ clickedGUID: GUID, _ selectedGUIDs: Set<GUID>) {
    guard let sn = self.con.displayStore.getSN(clickedGUID) else {
      NSLog("ERROR [\(treeID)] Clicked GUID not found: \(clickedGUID)")
      return
    }
    guard !sn.node.isEphemeral else {
      NSLog("DEBUG [\(treeID)] Ignoring request to build context menu: node is ephemeral")
      return
    }
    let clickedOnSelection = selectedGUIDs.contains(clickedGUID)
    NSLog("DEBUG [\(treeID)] User opened context menu on GUID=\(clickedGUID) isOnSelection=\(clickedOnSelection)")

    menu.removeAllItems()

    if clickedOnSelection && selectedGUIDs.count > 1 {
      // User right-clicked on selection -> apply context menu to all selected items:
      do {
        try self.buildContextMenuMultiple(menu, selectedGUIDs)
      } catch {
        self.con.reportError("Failed to build context menu", "While loading GUIDs: \(selectedGUIDs): \(error)")
      }
    } else {
      // Singular item, or singular selection (equivalent logic)
      do {
        try self.buildContextMenuSingle(menu, clickedGUID)
      } catch {
        self.con.reportError("Failed to build context menu", "While loading GUID: \(clickedGUID): \(error)")
      }
    }
  }

  /**
   Builds a context menu for multiple selected items.
  */
  private func buildContextMenuMultiple(_ menu: NSMenu, _ targetGUIDSet: Set<GUID>) throws {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG Building context menu items for multiple selection of \(targetGUIDSet.count) items")
    }
    let item = NSMenuItem(title: "\(targetGUIDSet.count) items selected", action: nil, keyEquivalent: "")
    item.isEnabled = false
    menu.addItem(item)

    var snList: [SPIDNodePair] = []
    for guid in targetGUIDSet {
      if let sn = self.con.displayStore.getSN(guid) {
        snList.append(sn)
      }
    }
    assert(snList.count == targetGUIDSet.count, "SNList size (\(snList.count)) does not match GUID count (\(targetGUIDSet.count))")


    if self.con.tree.hasCheckboxes {
      var item = MenuItemWithSNList(title: "Check All", action: #selector(self.con.treeActions.checkAll(_:)), keyEquivalent: "")
      item.snList = snList
      item.target = self.con.treeActions
      menu.addItem(item)

      item = MenuItemWithSNList(title: "Uncheck All", action: #selector(self.con.treeActions.uncheckAll(_:)), keyEquivalent: "")
      item.snList = snList
      item.target = self.con.treeActions
      menu.addItem(item)
    }

    var nodeLocalList: [Node] = []
    var nodeGDriveList: [Node] = []

    for sn in snList {
      if sn.node.isLive {
        if sn.spid.treeType == .LOCAL_DISK {
          nodeLocalList.append(sn.node)
        } else if sn.spid.treeType == .GDRIVE {
          nodeGDriveList.append(sn.node)
        }
      }
    }

    if nodeLocalList.count > 0 {
      let item = MenuItemWithNodeList(title: "Delete \(nodeLocalList.count) Items from Local Disk", action: #selector(self.con.treeActions.deleteSubtree(_:)), keyEquivalent: "")
      item.nodeList = nodeLocalList
      item.target = self.con.treeActions
      menu.addItem(item)
    }

    if nodeGDriveList.count > 0 {
      let item = MenuItemWithNodeList(title: "Delete \(nodeGDriveList.count) Items from Google Drive", action: #selector(self.con.treeActions.deleteSubtree(_:)), keyEquivalent: "")
      item.nodeList = nodeGDriveList
      item.target = self.con.treeActions
      menu.addItem(item)
    }
  }

  /**
   Builds a context menu for a single item.
  */
  private func buildContextMenuSingle(_ menu: NSMenu, _ targetGUID: GUID) throws {
    guard let sn = self.con.displayStore.getSN(targetGUID) else {
      NSLog("ERROR [\(treeID)] Clicked GUID not found: \(targetGUID)")
      return
    }

    let op: UserOp? = try self.con.backend.getLastPendingOp(deviceUID: sn.node.deviceUID, nodeUID: sn.node.uid)
    let singlePath = sn.spid.getSinglePath()

    if op != nil && op!.hasDst() {
      NSLog("DEBUG [\(treeID)] Building context menu items for src-dst op: \(op!)")

      // Split into separate entries for src and dst.

      // (1/2) Source node:
      let srcPath: String
      if op!.srcNode.uid == sn.node.uid {
        srcPath = singlePath
      } else {
        srcPath = op!.srcNode.firstPath
      }
      let srcItem = self.buildFullPathDisplayItem(preamble: "Src: ", op!.srcNode, singlePath: srcPath)
      menu.addItem(srcItem)

      if op!.srcNode.isLive {
        let srcSubmenu = NSMenu()
        menu.setSubmenu(srcSubmenu, for: srcItem)
        try self.buildMenuItemsForSingleNode(srcSubmenu, op!.srcNode, srcPath)
      } else {
        srcItem.isEnabled = false
      }

      menu.addItem(NSMenuItem.separator())

      // (1/2) Destination node:
      let dstPath: String
      if op!.dstNode!.uid == sn.node.uid {
        dstPath = singlePath
      } else {
        dstPath = op!.dstNode!.firstPath
      }
      let dstItem = self.buildFullPathDisplayItem(preamble: "Dst: ", op!.dstNode!, singlePath: dstPath)
      menu.addItem(dstItem)

      if op!.dstNode!.isLive {
        let dstSubmenu = NSMenu()
        menu.setSubmenu(dstSubmenu, for: dstItem)
        try self.buildMenuItemsForSingleNode(dstSubmenu, op!.dstNode!, dstPath)
      } else {
        dstItem.isEnabled = false
      }

      menu.addItem(NSMenuItem.separator())

    } else {
      let item = self.buildFullPathDisplayItem(sn.node, singlePath: sn.spid.getSinglePath())
      item.isEnabled = false
      menu.addItem(item)

      menu.addItem(NSMenuItem.separator())

      try self.buildMenuItemsForSingleNode(menu, sn.node, singlePath)
    }

    if sn.node.isDir {
      let item = MenuItemWithSNList(title: "Expand All", action: #selector(self.con.treeActions.expandAll(_:)), keyEquivalent: "")
      item.snList = [sn]
      item.target = self.con.treeActions
      menu.addItem(item)
    }

    if sn.node.isLive {
      menu.addItem(NSMenuItem.separator())
      let item = MenuItemWithSNList(title: "Refresh", action: #selector(self.con.treeActions.refreshSubtree(_:)), keyEquivalent: "")
      item.snList = [sn]
      item.target = self.con.treeActions
      menu.addItem(item)
    }
  }

  private func buildFullPathDisplayItem(preamble: String = "", _ node: Node, singlePath: String) -> NSMenuItem {
    let displayPath: String
    displayPath = "\(preamble)\(singlePath)"
    let item = NSMenuItem(title: displayPath, action: nil, keyEquivalent: "")
    item.toolTip = "The path of the selected item"
    return item
  }

  private func buildMenuItemsForSingleNode(_ menu: NSMenu, _ node: Node, _ singlePath: String) throws {
    NSLog("DEBUG [\(treeID)] Building context menu for node: \(node), singlePath: '\(singlePath)'")

    if node.isContainerNode {
      return
    }

    guard let sn: SPIDNodePair = try self.con.backend.getSNFor(nodeUID: node.uid, deviceUID: node.deviceUID, fullPath: singlePath) else {
      NSLog("ERROR [\(treeID)] Could not build context menu: backend couldn't find: \(node.nodeIdentifier)")
      return
    }

    if node.isLive && node.treeType == .LOCAL_DISK {
      let item = MenuItemWithNodeList(title: "Show in Finder", action: #selector(self.con.treeActions.showInFinder(_:)), keyEquivalent: "")
      item.nodeList = [node]
      item.target = self.con.treeActions
      menu.addItem(item)
    }

    if node.isLive && !node.isDir {
      if node.treeType == .GDRIVE {
        let item = MenuItemWithNodeList(title: "Download from Google Drive", action: #selector(self.con.treeActions.downloadFromGDrive(_:)), keyEquivalent: "")
        item.nodeList = [node]
        item.target = self.con.treeActions
        menu.addItem(item)
      } else if node.treeType == .LOCAL_DISK {
        let item = MenuItemWithSNList(title: "Open with Default App", action: #selector(self.con.treeActions.openFile(_:)), keyEquivalent: "")
        item.snList = [sn]
        item.target = self.con.treeActions
        menu.addItem(item)
      }
    }

    if !node.isLive {
      let item = NSMenuItem(title: "(does not exist)", action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
    }

    if node.isLive && node.isDir && self.con.canChangeRoot {
      let item = MenuItemWithSNList(title: "Go Into \"\(node.name)\"", action: #selector(self.con.treeActions.goIntoDir(_:)), keyEquivalent: "")
      item.snList = [sn]
      item.target = self.con.treeActions
      menu.addItem(item)
    }

    if node.isLive && !(type(of: node) is CategoryNode.Type) {
      var title = "\"\(node.name)\""
      if node.isDir {
        title = "Delete tree \(title)"
      } else {
        title = "Delete \(title)"
      }
      if node.treeType == .GDRIVE {
        title += " from Google Drive"
      }
      let item = MenuItemWithNodeList(title: title, action: #selector(self.con.treeActions.deleteSubtree(_:)), keyEquivalent: "")
      item.nodeList = [sn.node]
      item.target = self.con.treeActions
      menu.addItem(item)
    }
  }

}
