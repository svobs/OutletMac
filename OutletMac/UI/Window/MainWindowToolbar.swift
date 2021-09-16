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
    static let toolbarMoreActions = NSToolbarItem.Identifier("ToolbarMoreActionsItem")
    static let dragModePickerItem = NSToolbarItem.Identifier("DragModePickerItemGroup")
}

class DragMode {
    init(_ dragOperation: DragOperation, _ title: String, _ image: NSImage) {
        self.dragOperation = dragOperation
        self.title = title
        self.image = image
    }

    let dragOperation: DragOperation
    let title: String
    let image: NSImage
}

/**
 See doc: https://developer.apple.com/documentation/appkit/touch_bar/integrating_a_toolbar_and_touch_bar_into_your_app
 See example: https://github.com/marioaguzman/toolbar/blob/master/Toolbar/MainWindowController.swift
 */
class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    static let DRAG_MODE_LIST = [
        DragMode(.COPY, "Copy", NSImage(named: .modeCopy)!),
        DragMode(.MOVE, "Move", NSImage(named: .modeMove)!)
        ]

    override init(identifier: NSToolbar.Identifier) {
        super.init(identifier: identifier)
        self.delegate = self
        self.displayMode = .default
        self.sizeMode = .regular
        self.allowsUserCustomization = true
        self.autosavesConfiguration = true
    }

    let isBordered: Bool = true

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
        return [.dragModePickerItem, .flexibleSpace, .space, .toolbarMoreActions] // Whatever items you want to allow
    }

    /**
     Tell MacOS which items to display when the app is launched for the first time.
     */
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.dragModePickerItem, .flexibleSpace, .space, .toolbarMoreActions] // Whatever items you want as default
    }

    /**
     Create a new NSToolbarItem instance and set its attributes based on the provided item identifier.
     */
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        if  itemIdentifier == NSToolbarItem.Identifier.dragModePickerItem {
            var titleList: [String] = []
            var imageList: [NSImage] = []

            for dragMode in MainWindowToolbar.DRAG_MODE_LIST {
                titleList.append(dragMode.title)
                imageList.append(dragMode.image)
            }

            // This will either be a segmented control or a drop down depending on your available space.
            // NOTE: When you set the target as nil and use the string method to define the Selector, it will go down the Responder Chain,
            // which in this app, this method is in AppDelegate. Neat!
            let toolbarItem = NSToolbarItemGroup(itemIdentifier: itemIdentifier, images: imageList, selectionMode: .selectOne, labels: titleList,
                    target: nil, action: Selector(("toolPickerDidSelectItem:")) )

            toolbarItem.label = "Drag Mode"
            toolbarItem.paletteLabel = "Drag Mode"
            toolbarItem.toolTip = "Set the default mode for Drag & Drop (Copy or Move)"
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

    func getItemIfVisible(_ itemIdentifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        guard let visibleItems = self.visibleItems else {
            NSLog("DEBUG getItemIfVisible(): no items visible")
            return nil
        }

        for item in visibleItems {
            if item.itemIdentifier == itemIdentifier {
                return item
            }
        }
        return nil
    }

    private static func indexForDragOperation(_ dragOperation: DragOperation) -> Int? {
        var index = 0
        for mode in MainWindowToolbar.DRAG_MODE_LIST {
            if mode.dragOperation == dragOperation {
                return index
            }
            index += 1
        }
        return nil
    }

    func setDragMode(_ dragOperation: DragOperation) {
        guard dragOperation == .MOVE || dragOperation == .COPY else {
            NSLog("ERROR selectDragMode(): invalid: \(dragOperation)")
            return
        }

        if let dragModeItem = self.getItemIfVisible(NSToolbarItem.Identifier.dragModePickerItem) {
            if let itemGroup = dragModeItem as? NSToolbarItemGroup {
                if let index = MainWindowToolbar.indexForDragOperation(dragOperation) {
                    NSLog("DEBUG selectDragMode(): selecting index: \(index)")
                    // This will not fire listeners however. We should have set those values elsewhere.
                    itemGroup.setSelected(true, at: index)
                }
            }
        }
    }
}
