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
    let actionType: ActionType // can be handled (A) either here in the FE, or (B) if targetGUIDList is non-empty, sent back to the BE for processing
    var targetGUIDList: [GUID] = []  // if the BE wants to handle the given action, it will populate this so that it can be sent back to the BE
    var submenuItemList: [MenuItemMeta]  // if empty, this menu item is not a submenu
    var targetUID: UID

    init(itemType: MenuItemType, title: String, actionType: ActionType, targetUID: UID = NULL_UID) {
        self.itemType = itemType
        self.title = title
        self.actionType = actionType
        self.submenuItemList = []
        self.targetUID = targetUID
    }

    var description: String {
        return "MenuItemMeta[type=\(itemType) actionType=\(actionType) title='\(title) submenu=\(submenuItemList)']"
    }
}

class SubmenuItemMeta : MenuItemMeta {
    init(title: String) {
        super.init(itemType: .NORMAL, title: title, actionType: .BUILTIN(.NO_ACTION))
    }
}
