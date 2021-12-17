//
// Created by Matthew Svoboda on 21/12/14.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Foundation

class MenuItemMeta: CustomStringConvertible {
    let itemType: MenuItemType
    let title: String
    let actionID: ActionID
    var targetGUIDList: [GUID] = []
    var submenuItemList: [MenuItemMeta]

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
