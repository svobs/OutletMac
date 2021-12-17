//
//  ContextMenu.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/17.
//

import SwiftUI

class GeneratedMenuItem: NSMenuItem {
  var snList: [SPIDNodePair]
  var menuItemMeta: MenuItemMeta // provided by the backend

  public init(_ snList: [SPIDNodePair], _ menuItemMeta: MenuItemMeta, action selector: Selector?) {
    self.snList = snList
    self.menuItemMeta = menuItemMeta
    super.init(title: menuItemMeta.title, action: selector, keyEquivalent: "")
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


class TreeContextMenu {
  weak var con: TreePanelControllable! = nil  // Need to set this in parent controller's start() method

  var treeID: String {
    return con.treeID
  }

  func rebuildMenuFor(_ menu: NSMenu, _ clickedGUID: GUID, _ selectedGUIDs: Set<GUID>) {
    guard let snClicked = self.con.displayStore.getSN(clickedGUID) else {
      NSLog("ERROR [\(treeID)] Clicked GUID not found: \(clickedGUID)")
      return
    }
    guard !snClicked.node.isEphemeral else {
      NSLog("DEBUG [\(treeID)] Ignoring request to build context menu: clicked node is ephemeral")
      return
    }
    let clickedOnSelection = selectedGUIDs.contains(clickedGUID)
    NSLog("DEBUG [\(treeID)] User opened context menu on GUID=\(clickedGUID) selectedItems=\(selectedGUIDs.count) isOnSelection=\(clickedOnSelection)")

    menu.removeAllItems()

    var snList: [SPIDNodePair] = []
    if clickedOnSelection && selectedGUIDs.count > 1 {
      // User right-clicked on selection -> apply context menu to all selected items:
      for guid in selectedGUIDs {
        if let sn = self.con.displayStore.getSN(guid) {
          snList.append(sn)
        }
      }
      assert(snList.count == selectedGUIDs.count, "SNList size (\(snList.count)) does not match selected GUID count (\(selectedGUIDs.count))")

    } else {
      snList.append(snClicked)
    }

    do {
      let menuItemList: [MenuItemMeta] = try self.con.backend.getContextMenu(treeID: self.treeID, snList.map { sn in sn.spid })
      buildMenuFromMeta(menuItemList, menu: menu, snList)
    } catch {
      self.con.reportError("Failed to build context menu", "\(error)")
    }
  }

  private func buildMenuFromMeta(_ itemMetaList: [MenuItemMeta], menu: NSMenu, _ snList: [SPIDNodePair]) {
    for itemMeta in itemMetaList {
      let item = GeneratedMenuItem(snList, itemMeta, action: #selector(self.con.treeActions.executeMenuAction(_:)))
      item.target = self.con.treeActions
      menu.addItem(item)

      if itemMeta.submenuItemList.count > 0 {
        let submenu = NSMenu()
        menu.setSubmenu(submenu, for: item)
        buildMenuFromMeta(itemMeta.submenuItemList, menu: submenu, snList)
      }
    }
  }

}
