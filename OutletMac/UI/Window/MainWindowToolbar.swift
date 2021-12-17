//
// Created by Matthew Svoboda on 21/9/12.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa

extension NSImage.Name {
    static let modeCopy = NSImage.Name("ModeCopy")
    static let modeMove = NSImage.Name("ModeMove")

    static let promptUser = NSImage.Name("PromptUser")

    static let skipFolder = NSImage.Name("Folder-Skip")
    static let replaceFolder = NSImage.Name("Folder-Replace")
    static let keepBothFolders = NSImage.Name("Folder-KeepBoth")
    static let mergeFolders = NSImage.Name("Folder-Merge")

    static let skipFile = NSImage.Name("File-Skip")
    static let replaceFileAlways = NSImage.Name("File-ReplaceAlways")
    static let replaceOldFileWithNewOnly = NSImage.Name("File-ReplaceOldWithNewOnly")
    static let keepBothFiles = NSImage.Name("File-KeepBoth")
    static let keepBothFilesIfDifferent = NSImage.Name("File-KeepBothIfDifferent")
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

enum PickerItemValue: Equatable {
    case DragMode(DragOperation)
    case DirPolicy(DirConflictPolicy)
    case FilePolicy(FileConflictPolicy)
}

private class PickerItem {
    init(_ value: PickerItemValue, _ title: String, _ image: NSImage) {
        self.value = value
        self.title = title
        self.image = image
    }

    let value: PickerItemValue
    let title: String
    let image: NSImage
}

private class PickerGroup: Hashable {
    static func ==(lhs: PickerGroup, rhs: PickerGroup) -> Bool {
        // We are really just implementing Hashable to make the compiler happy, but this field should be enough to be unique for our purposes
        return lhs.groupLabel == rhs.groupLabel
    }

    func hash(into hasher: inout Hasher) {
        // ditto as above
        hasher.combine(groupLabel)
    }

    init(_ itemList: [PickerItem], groupLabel: String, tooltipTemplate: String) {
        self.itemList = itemList
        self.groupLabel = groupLabel
        self.tooltipTemplate = tooltipTemplate
    }

    let itemList: [PickerItem]
    let groupLabel: String
    let tooltipTemplate: String
}

/**
 See doc: https://developer.apple.com/documentation/appkit/touch_bar/integrating_a_toolbar_and_touch_bar_into_your_app
 See example: https://github.com/marioaguzman/toolbar/blob/master/Toolbar/MainWindowController.swift
 */
class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    private static let dragModeGroup = PickerGroup(
            [
                PickerItem(.DragMode(.COPY), "Copy", NSImage(named: .modeCopy)!),
                PickerItem(.DragMode(.MOVE), "Move", NSImage(named: .modeMove)!)
            ],
            groupLabel: "Drag Mode",
            tooltipTemplate: "Set the default mode for Drag & Drop (Copy or Move)")

    private static let dirConflictPolicyGroup = PickerGroup(
            [
                PickerItem(.DirPolicy(.PROMPT), "Prompt user", NSImage(named: .promptUser)!),
                PickerItem(.DirPolicy(.SKIP), "Skip folder", NSImage(named: .skipFolder)!),
                PickerItem(.DirPolicy(.REPLACE), "Replace folder", NSImage(named: .replaceFolder)!),
                PickerItem(.DirPolicy(.RENAME), "Keep both folders", NSImage(named: .keepBothFolders)!),
                PickerItem(.DirPolicy(.MERGE), "Merge", NSImage(named: .mergeFolders)!)
            ],
            groupLabel: "Folder Conflict Policy",
            tooltipTemplate: "When moving or copying: what to do when the destination already contains a folder with the same name as a folder being copied")

    private static let fileConflictPolicyGroup = PickerGroup(
            [
                PickerItem(.FilePolicy(.PROMPT), "Prompt user", NSImage(named: .promptUser)!),
                PickerItem(.FilePolicy(.SKIP), "Skip file", NSImage(named: .skipFile)!),
                PickerItem(.FilePolicy(.REPLACE_ALWAYS), "Overwrite always", NSImage(named: .replaceFileAlways)!),
                PickerItem(.FilePolicy(.REPLACE_IF_OLDER_AND_DIFFERENT), "Overwrite old with new only", NSImage(named: .replaceOldFileWithNewOnly)!),
                PickerItem(.FilePolicy(.RENAME_ALWAYS), "Keep both always", NSImage(named: .keepBothFiles)!),
                PickerItem(.FilePolicy(.RENAME_IF_DIFFERENT), "Keep both only if different", NSImage(named: .modeMove)!)
            ],
            groupLabel: "File Conflict Policy",
            tooltipTemplate: "When moving or copying: what to do when the destination already contains a file with the same name as a file being copied")

    private static let groupMap: [NSToolbarItem.Identifier : PickerGroup] = [
        NSToolbarItem.Identifier.dragModePicker: dragModeGroup,
        NSToolbarItem.Identifier.dirConflictPolicyPicker: dirConflictPolicyGroup,
        NSToolbarItem.Identifier.fileConflictPolicyPicker: fileConflictPolicyGroup
    ]

    private static func getGroup(_ identifier: NSToolbarItem.Identifier) -> PickerGroup {
        if let group = MainWindowToolbar.groupMap[identifier] {
            return group
        } else {
            fatalError("Identifier does not correspond to a picker group: \(identifier)")
        }
    }

//    static let DIR_CONFLICT_POLICY_LIST: [PickerItem<DirConflictPolicy>] = [
//    ]
//
//    static let FILE_CONFLICT_POLICY_LIST: [PickerItem<FileConflictPolicy>] = [

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
        return [.dragModePicker, .dirConflictPolicyPicker, .fileConflictPolicyPicker, .flexibleSpace, .space, .toolbarMoreActions]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.dragModePicker, .dirConflictPolicyPicker, .fileConflictPolicyPicker]
    }

    /**
     Tell MacOS which items to display when the app is launched for the first time.
     */
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.dragModePicker, .dirConflictPolicyPicker, .fileConflictPolicyPicker, .flexibleSpace, .space, .toolbarMoreActions]
    }

    /**
     willBeInsertedIntoToolbar:
     Create a new NSToolbarItem instance and set its attributes based on the provided item identifier.
     */
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        if let group = MainWindowToolbar.groupMap[itemIdentifier] {
            return self.createSingleSelectionPickerGroup(itemIdentifier, group)
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

    private func createSingleSelectionPickerGroup(_ itemIdentifier: NSToolbarItem.Identifier, _ group: PickerGroup) -> NSToolbarItemGroup {

        var titleList: [String] = []
        var imageList: [NSImage] = []

        for itemMeta in group.itemList {
            titleList.append(itemMeta.title)
            imageList.append(itemMeta.image)
        }

        // This will either be a segmented control or a drop down depending on your available space.
        // NOTE: When you set the target as nil and use the string method to define the Selector, it will go down the Responder Chain,
        // which in this app, this method is in AppDelegate. Neat!
        let itemGroup = NSToolbarItemGroup(itemIdentifier: itemIdentifier, images: imageList, selectionMode: .selectOne, labels: titleList,
                                             target: nil, action: Selector(("toolbarPickerDidSelectItem:")) )

      itemGroup.label = group.groupLabel
      itemGroup.isEnabled = true
      itemGroup.paletteLabel = group.groupLabel
      itemGroup.toolTip = group.tooltipTemplate // TODO: display current value using template
        return itemGroup
    }

    func getItemForIdentifier(_ itemIdentifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        assert(self.items.count > 0, "No items in toolbar!")

        for item in self.items {
            if item.itemIdentifier == itemIdentifier {
                return item
            }
        }
        return nil
    }

    private static func indexForPickerValue(_ pickerValue: PickerItemValue, _ pickerItemList: [PickerItem]) -> Int? {
        var index = 0
        for item in pickerItemList {
            if item.value == pickerValue {
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

        self.setToolbarSelection(.dragModePicker, .DragMode(dragOperation))
    }

    func setToolbarSelection(_ toolbarIdentifier: NSToolbarItem.Identifier, _ pickerItemValue: PickerItemValue) {
        NSLog("DEBUG Entered setToolbarSelection(): identifier='\(toolbarIdentifier.rawValue)', pickerItemValue=\(pickerItemValue)")

        if let item = self.getItemForIdentifier(toolbarIdentifier) {
            let group = MainWindowToolbar.getGroup(toolbarIdentifier)
            if let itemGroup = item as? NSToolbarItemGroup {
                if let index = MainWindowToolbar.indexForPickerValue(pickerItemValue, group.itemList) {
                    NSLog("DEBUG setToolbarSelection(): selecting index: \(index) for identifier '\(toolbarIdentifier.rawValue)'")
                    // This will not fire listeners however. We should have set those values elsewhere.
                    itemGroup.setSelected(true, at: index)
//                    let pickerItem = group.itemList[index]
                    itemGroup.toolTip = group.tooltipTemplate //+ "\n\n(current value: \(String(pickerItem.title)))"  // TODO: this doesn't update
                }
            }
        }
    }

    static func getValueFromIndex(_ selectedIndex: Int, _ groupIdentifier: NSToolbarItem.Identifier) throws -> PickerItemValue? {
        let pickerList = MainWindowToolbar.getGroup(groupIdentifier).itemList
        guard selectedIndex < pickerList.count else {
            throw OutletError.invalidArgument("Index \(selectedIndex) is invalid for group \(groupIdentifier)")
        }
        return pickerList[selectedIndex].value
    }

}
