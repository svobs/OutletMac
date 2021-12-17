//
// Created by Matthew Svoboda on 21/12/14.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Foundation

/*
 Container for metadata describing the appearance and behavior of an item in a context menu. These can be nested to describe submenus.
 */
class MenuItemMeta: CustomStringConvertible {
    let itemType: MenuItemType
    let title: String
    let actionID: ActionID  // can be handled (A) either here in the FE, or (B) if targetGUIDList is non-empty, sent back to the BE for processing
    var targetGUIDList: [GUID] = []  // if the BE wants to handle the given action, it will populate this so that it can be sent back to the BE
    var submenuItemList: [MenuItemMeta]  // if empty, this menu item is not a submenu

    init(itemType: MenuItemType, title: String, actionID: ActionID) {
        self.itemType = itemType
        self.title = title
        self.actionID = actionID
        self.submenuItemList = []
    }

    var description: String {
        return "MenuItemMeta[type=\(itemType) actionID=\(actionID) title='\(title) submenu=\(submenuItemList)']"
    }
}
