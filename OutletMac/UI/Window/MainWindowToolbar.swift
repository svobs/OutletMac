//
// Created by Matthew Svoboda on 21/9/12.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa

extension NSImage.Name {
    static let modeCopy = NSImage.Name("ModeCopy")
    static let modeMove = NSImage.Name("ModeMove")
}

extension NSToolbar.Identifier {
    static let mainWindowToolbarIdentifier = NSToolbar.Identifier("MainWindowToolbar")
}

extension NSToolbarItem.Identifier {
    static let toolbarItemMoreInfo = NSToolbarItem.Identifier("ToolbarMoreInfoItem")

    /// Example of `NSMenuToolbarItem`
    static let toolbarMoreActions = NSToolbarItem.Identifier("ToolbarMoreActionsItem")

    /// Example of `NSToolbarItemGroup`
    static let toolPickerItem = NSToolbarItem.Identifier("ToolPickerItemGroup")
}

/**
 See doc: https://developer.apple.com/documentation/appkit/touch_bar/integrating_a_toolbar_and_touch_bar_into_your_app
 See example: https://github.com/marioaguzman/toolbar/blob/master/Toolbar/MainWindowController.swift
 */
class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    override init(identifier: NSToolbar.Identifier) {
        super.init(identifier: identifier)
        self.delegate = self
        self.displayMode = .default
        self.sizeMode = .regular
        self.allowsUserCustomization = true
        self.autosavesConfiguration = true
    }

    let isBordered: Bool = true
    let modeCopyImage = NSImage(named: .modeCopy)!
    let modeMoveImage = NSImage(named: .modeMove)!

    let actionsMenu: NSMenu = {
        var menu = NSMenu(title: "")
        menu.items = [
            NSMenuItem(title: "Open", action: nil, keyEquivalent: "o"),
            NSMenuItem.separator(),
            NSMenuItem(title: "Get info", action: nil, keyEquivalent: "i"),
            NSMenuItem(title: "Rename", action: nil, keyEquivalent: "r"),
            NSMenuItem(title: "Show in Finder", action: nil, keyEquivalent: "F"),
            NSMenuItem.separator(),
            NSMenuItem(title: "Move to trash...", action: nil, keyEquivalent: "t")
        ]
        return menu
    }()

    /**
     Tell MacOS which items are allowed in this toolbar, for customization.
     */
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toolPickerItem, .flexibleSpace, .space, .toolbarMoreActions] // Whatever items you want to allow
    }

    /**
     Tell MacOS which items to display when the app is launched for the first time.
     */
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toolPickerItem, .flexibleSpace, .space, .toolbarMoreActions] // Whatever items you want as default
    }

    /**
     Create a new NSToolbarItem instance and set its attributes based on the provided item identifier.
     */
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        if  itemIdentifier == NSToolbarItem.Identifier.toolPickerItem {
            let titleList = ["Copy", "Move"]
            let imageList: [NSImage] = [modeCopyImage, modeMoveImage]

            // This will either be a segmented control or a drop down depending on your available space.
            // NOTE: When you set the target as nil and use the string method to define the Selector, it will go down the Responder Chain,
            // which in this app, this method is in AppDelegate. Neat!
            let toolbarItem = NSToolbarItemGroup(itemIdentifier: itemIdentifier, images: imageList, selectionMode: .selectOne, labels: titleList,
                    target: nil, action: Selector(("toolbarPickerDidSelectItem:")) )

            toolbarItem.label = "Drag Mode"
            toolbarItem.paletteLabel = "Drag Mode"
            toolbarItem.toolTip = "Change the selected drag mode"
            toolbarItem.selectedIndex = 0
            return toolbarItem
        }

        if  itemIdentifier == NSToolbarItem.Identifier.toolbarMoreActions {
            let toolbarItem = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            toolbarItem.showsIndicator = true // Make `false` if you don't want the down arrow to be drawn
            toolbarItem.menu = self.actionsMenu
            toolbarItem.label = "More Actions"
            toolbarItem.paletteLabel = "More Actions"
            toolbarItem.toolTip = "Displays available actions for the selected node"
            toolbarItem.isBordered = isBordered
            if  #available(macOS 11.0, *) {
                toolbarItem.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "")
            } else {
                toolbarItem.image = NSImage(named: NSImage.advancedName)
            }
            return toolbarItem
        }

        return nil
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        if  item.itemIdentifier == NSToolbarItem.Identifier.toolbarMoreActions {
            return true
        }
        // TODO
        return true
    }

}
