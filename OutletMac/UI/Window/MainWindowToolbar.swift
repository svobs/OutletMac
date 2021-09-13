//
// Created by Matthew Svoboda on 21/9/12.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa

class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    override init(identifier: NSToolbar.Identifier) {
        super.init(identifier: identifier)
        self.delegate = self
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        return nil
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.print, .showColors, .flexibleSpace,. space] // Whatever items you want to allow
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .showColors] // Whatever items you want as default
    }
}
