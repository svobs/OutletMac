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
    static let toolbarItemMoreInfo = NSToolbarItem.Identifier("ToolbarMoreInfo-Item")
    static let toolbarMoreActions = NSToolbarItem.Identifier("ToolbarMoreActions-Item")
    static let dragModePicker = NSToolbarItem.Identifier("DragModePicker-ItemGroup")
    static let dirConflictPolicyPicker = NSToolbarItem.Identifier("DirConflictPolicyPicker-ItemGroup")
    static let fileConflictPolicyPicker = NSToolbarItem.Identifier("FileConflictPolicyPicker-ItemGroup")
}

class PickerItem<Value> where Value : Hashable {
    init(_ value: Value, _ title: String, _ image: NSImage) {
        self.value = value
        self.title = title
        self.image = image
    }

    let value: Value
    let title: String
    let image: NSImage
}

/**
 See doc: https://developer.apple.com/documentation/appkit/touch_bar/integrating_a_toolbar_and_touch_bar_into_your_app
 See example: https://github.com/marioaguzman/toolbar/blob/master/Toolbar/MainWindowController.swift
 */
class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    static let DRAG_MODE_LIST: [PickerItem<DragOperation>] = [
        PickerItem<DragOperation>(.COPY, "Copy", NSImage(named: .modeCopy)!),
        PickerItem<DragOperation>(.MOVE, "Move", NSImage(named: .modeMove)!)
        ]

    // FIXME: add new icons for all of these!
    static let DIR_CONFLICT_POLICY_LIST: [PickerItem<DirConflictPolicy>] = [
        PickerItem<DirConflictPolicy>(.PROMPT, "Prompt user", NSImage(named: .modeCopy)!),
        PickerItem<DirConflictPolicy>(.SKIP, "Skip folder", NSImage(named: .modeMove)!),
        PickerItem<DirConflictPolicy>(.REPLACE, "Replace entire folder", NSImage(named: .modeMove)!),
        PickerItem<DirConflictPolicy>(.RENAME, "Keep both folders", NSImage(named: .modeMove)!),
        PickerItem<DirConflictPolicy>(.MERGE, "Merge folders", NSImage(named: .modeMove)!)
    ]

    // FIXME: add new icons for all of these!
    static let FILE_CONFLICT_POLICY_LIST: [PickerItem<FileConflictPolicy>] = [
        PickerItem<FileConflictPolicy>(.PROMPT, "Prompt user", NSImage(named: .modeCopy)!),
        PickerItem<FileConflictPolicy>(.SKIP, "Skip", NSImage(named: .modeMove)!),
        PickerItem<FileConflictPolicy>(.REPLACE_ALWAYS, "Always overwrite destination file", NSImage(named: .modeMove)!),
        PickerItem<FileConflictPolicy>(.REPLACE_IF_OLDER_AND_DIFFERENT, "Overwrite destination file if it is older and different", NSImage(named: .modeMove)!),
        PickerItem<FileConflictPolicy>(.RENAME_ALWAYS, "Keep both always (even if they are identical)", NSImage(named: .modeMove)!),
        PickerItem<FileConflictPolicy>(.RENAME_IF_DIFFERENT, "Keep both if different (& skip if identical)", NSImage(named: .modeMove)!)
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
        return [.dragModePicker, .dirConflictPolicyPicker, .fileConflictPolicyPicker, .flexibleSpace, .space, .toolbarMoreActions] // Whatever items you want to allow
    }

    /**
     Tell MacOS which items to display when the app is launched for the first time.
     */
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.dragModePicker, .dirConflictPolicyPicker, .fileConflictPolicyPicker, .flexibleSpace, .space, .toolbarMoreActions] // Whatever items you want as default
    }

    /**
     Create a new NSToolbarItem instance and set its attributes based on the provided item identifier.
     */
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        if  itemIdentifier == NSToolbarItem.Identifier.dragModePicker {
            return self.createSingleSelectionPickerGroup(itemIdentifier, MainWindowToolbar.DRAG_MODE_LIST,
                    actionSelectorName: "dragModePickerDidSelectItem:",
                    groupLabel: "Drag Mode", toolTip: "Set the default mode for Drag & Drop (Copy or Move)")
        }

        if  itemIdentifier == NSToolbarItem.Identifier.dirConflictPolicyPicker {
            return self.createSingleSelectionPickerGroup(itemIdentifier, MainWindowToolbar.DIR_CONFLICT_POLICY_LIST,
                    actionSelectorName: "dirConflictPolicyPickerDidSelectItem:",
                    groupLabel: "Folder Conflict Policy", toolTip: "When moving or copying: what to do when the destination already contains a folder with the same name as a folder being copied")
        }

        if  itemIdentifier == NSToolbarItem.Identifier.fileConflictPolicyPicker {
            return self.createSingleSelectionPickerGroup(itemIdentifier, MainWindowToolbar.FILE_CONFLICT_POLICY_LIST,
                    actionSelectorName: "fileConflictPolicyPickerDidSelectItem:",
                    groupLabel: "File Conflict Policy", toolTip: "When moving or copying: what to do when the destination already contains a file with the same name as a file being copied")
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

    private func createSingleSelectionPickerGroup<ItemValue>(_ itemIdentifier: NSToolbarItem.Identifier, _ pickerItemList: [PickerItem<ItemValue>],
                                                  actionSelectorName: String, groupLabel: String, toolTip: String) -> NSToolbarItemGroup {

        var titleList: [String] = []
        var imageList: [NSImage] = []

        for item in pickerItemList {
            titleList.append(item.title)
            imageList.append(item.image)
        }

        // This will either be a segmented control or a drop down depending on your available space.
        // NOTE: When you set the target as nil and use the string method to define the Selector, it will go down the Responder Chain,
        // which in this app, this method is in AppDelegate. Neat!
        let toolbarItem = NSToolbarItemGroup(itemIdentifier: itemIdentifier, images: imageList, selectionMode: .selectOne, labels: titleList,
                target: nil, action: Selector((actionSelectorName)) )

        toolbarItem.label = groupLabel
        toolbarItem.paletteLabel = groupLabel
        toolbarItem.toolTip = toolTip
        return toolbarItem
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
            if mode.value == dragOperation {
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

        if let dragModeItem = self.getItemIfVisible(NSToolbarItem.Identifier.dragModePicker) {
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
