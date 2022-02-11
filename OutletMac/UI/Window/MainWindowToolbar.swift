//
// Created by Matthew Svoboda on 21/9/12.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa

//extension NSToolbar.Identifier {
//    static let mainWindowToolbarIdentifier = NSToolbar.Identifier("MainWindowToolbar")
//}

// Group identifier definitions:
extension NSToolbarItem.Identifier {
    static let toolbarItemMoreInfo = NSToolbarItem.Identifier("ToolbarMoreInfo-Item")
    static let toolbarMoreActions = NSToolbarItem.Identifier("ToolbarMoreActions-Item")
    static let dragModePicker = NSToolbarItem.Identifier("DragModePicker-ItemGroup")
    static let dirConflictPolicyPicker = NSToolbarItem.Identifier("DirConflictPolicyPicker-ItemGroup")
    static let fileConflictPolicyPicker = NSToolbarItem.Identifier("FileConflictPolicyPicker-ItemGroup")
}

/**
 See doc: https://developer.apple.com/documentation/appkit/touch_bar/integrating_a_toolbar_and_touch_bar_into_your_app
 See example: https://github.com/marioaguzman/toolbar/blob/master/Toolbar/MainWindowController.swift
 */
class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    // Maps each NSToolbarItem.Identifier to a group
    private static let groupMap: [NSToolbarItem.Identifier : PickerGroup] = [
        NSToolbarItem.Identifier.dragModePicker: ToolStateSpace.dragModeGroup,
        NSToolbarItem.Identifier.dirConflictPolicyPicker: ToolStateSpace.dirConflictPolicyGroup,
        NSToolbarItem.Identifier.fileConflictPolicyPicker: ToolStateSpace.fileConflictPolicyGroup
    ]

    private static func getGroup(_ identifier: NSToolbarItem.Identifier) -> PickerGroup {
        if let group = MainWindowToolbar.groupMap[identifier] {
            return group
        } else {
            fatalError("Identifier does not correspond to a picker group: \(identifier)")
        }
    }

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
                                           target: nil, action: #selector(OutletMacApp.toolbarPickerDidSelectItem))

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

    private static func indexForPickerItemIdentifier(_ pickerItemIdentifier: PickerItemIdentifier, _ pickerItemList: [PickerItem]) -> Int? {
        var index = 0
        for item in pickerItemList {
            if item.identifier == pickerItemIdentifier {
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

    func setToolbarSelection(_ toolbarIdentifier: NSToolbarItem.Identifier, _ pickerItemIdentifier: PickerItemIdentifier) {
        NSLog("DEBUG Entered setToolbarSelection(): identifier='\(toolbarIdentifier.rawValue)', pickerItemIdentifier=\(pickerItemIdentifier)")

        if let item = self.getItemForIdentifier(toolbarIdentifier) {
            let group = MainWindowToolbar.getGroup(toolbarIdentifier)
            if let itemGroup = item as? NSToolbarItemGroup {
                if let index = MainWindowToolbar.indexForPickerItemIdentifier(pickerItemIdentifier, group.itemList) {
                    NSLog("DEBUG setToolbarSelection(): selecting index: \(index) for identifier '\(toolbarIdentifier.rawValue)'")
                    // This will not fire listeners however. We should have set those values elsewhere.
                    itemGroup.setSelected(true, at: index)
//                    let pickerItem = group.itemList[index]
                    itemGroup.toolTip = group.tooltipTemplate //+ "\n\n(current value: \(String(pickerItem.title)))"  // TODO: this doesn't update
                }
            }
        }
    }

    static func getPickerItemIdentifierFromIndex(_ selectedIndex: Int, _ groupIdentifier: NSToolbarItem.Identifier) throws -> PickerItemIdentifier? {
        let pickerList = MainWindowToolbar.getGroup(groupIdentifier).itemList
        guard selectedIndex < pickerList.count else {
            throw OutletError.invalidArgument("Index \(selectedIndex) is invalid for group \(groupIdentifier)")
        }
        return pickerList[selectedIndex].identifier
    }

}
