//
// Created by Matthew Svoboda on 21/12/14.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Foundation

class ContextMenuItem: CustomStringConvertible {
    let itemType: MenuItemType
    let title: String
    let actionID: UInt32
    var submenuItemList: [ContextMenuItem]

    init(itemType: MenuItemType, title: String, actionID: UInt32) {
        self.itemType = itemType
        self.title = title
        self.actionID = actionID
        self.submenuItemList = []
    }

    var description: String {
        return "ContextMenuItem[type=\(itemType) actionID=\(actionID) title='\(title) submenu=\(submenuItemList)']"
    }
}
