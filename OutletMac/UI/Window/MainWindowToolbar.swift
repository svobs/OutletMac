//
// Created by Matthew Svoboda on 21/9/12.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa

extension NSViewController: NSUserInterfaceValidations {
    public func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        NSLog("ERROR [ViewController] Entered validateUserInterfaceItem()")
        switch item.action {

        default: return true
        }
    }
}

/*
 NSToolbarItem Identifier (NSTIID) definitions:
 */
extension NSToolbarItem.Identifier {
    // Items:
    static let toolbarItemMoreInfo = NSToolbarItem.Identifier("ToolbarMoreInfo-Item")
    static let toolbarMoreActions = NSToolbarItem.Identifier("ToolbarMoreActions-Item")
    // Groups:
    static let dragModePicker = NSToolbarItem.Identifier("DragModePicker-ItemGroup")
    static let dirConflictPolicyPicker = NSToolbarItem.Identifier("DirConflictPolicyPicker-ItemGroup")
    static let fileConflictPolicyPicker = NSToolbarItem.Identifier("FileConflictPolicyPicker-ItemGroup")
}

class MainWindowToolbarItemGroup: NSToolbarItemGroup {
    override func validate() {
        NSLog("ERROR VALIDATING!")
    }
}

/**
 See doc: https://developer.apple.com/documentation/appkit/touch_bar/integrating_a_toolbar_and_touch_bar_into_your_app
 See example: https://github.com/marioaguzman/toolbar/blob/master/Toolbar/MainWindowController.swift
 */
class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    // Maps each NSToolbarItem.Identifier to a group
    private static let groupIdentifierMap: [NSToolbarItem.Identifier : PickerGroup] = [
        NSToolbarItem.Identifier.dragModePicker: ToolStateSpace.dragModeGroup,
        NSToolbarItem.Identifier.dirConflictPolicyPicker: ToolStateSpace.dirConflictPolicyGroup,
        NSToolbarItem.Identifier.fileConflictPolicyPicker: ToolStateSpace.fileConflictPolicyGroup
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

        if let group = MainWindowToolbar.groupIdentifierMap[itemIdentifier] {
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
        let itemGroup = MainWindowToolbarItemGroup(itemIdentifier: itemIdentifier, images: imageList,
                selectionMode: .selectOne, labels: titleList, target: self, action: #selector(MainWindowToolbar.toolbarPickerDidSelectItem))

        itemGroup.label = group.groupLabel
//        itemGroup.isEnabled = true    // TODO: try excluding this
        itemGroup.paletteLabel = group.groupLabel
        itemGroup.toolTip = group.tooltipTemplate // TODO: display current value using template
        return itemGroup
    }

    func setToolbarSelection(_ pickerItemIdentifier: PickerItemIdentifier) {
        NSLog("DEBUG Entered setToolbarSelection(): pickerItemIdentifier=\(pickerItemIdentifier)")

        if let toolbarGroup = self.getToolbarItemGroupForPickerItemIdentifier(pickerItemIdentifier) {
            if let index = MainWindowToolbar.indexForPickerItemIdentifier(pickerItemIdentifier) {
                NSLog("DEBUG setToolbarSelection(): selecting index: \(index) for pickerItemIdentifier '\(pickerItemIdentifier)'")
                // This will not fire listeners however. We should have set those values elsewhere.
                toolbarGroup.setSelected(true, at: index)
                let pickerGroup = MainWindowToolbar.getPickerGroupForNSTIID(toolbarGroup.itemIdentifier)
                toolbarGroup.toolTip = pickerGroup.tooltipTemplate //+ "\n\n(current value: \(String(pickerItem.title)))"  // TODO: this doesn't update
            }
        }
    }

    // --------------------------------------------------------------------------------------------
    // Lookup Functions

    private static func getPickerGroupForNSTIID(_ identifier: NSToolbarItem.Identifier) -> PickerGroup {
        if let group = MainWindowToolbar.groupIdentifierMap[identifier] {
            return group
        } else {
            fatalError("Identifier does not correspond to a picker group: \(identifier)")
        }
    }

    private static func getGroupNSTIIDFromPickerItemIdentifier(_ pickerItemIdentifier: PickerItemIdentifier) -> NSToolbarItem.Identifier {
        switch pickerItemIdentifier {
        case .DragMode:
            return NSToolbarItem.Identifier.dragModePicker
        case .DirPolicy:
            return NSToolbarItem.Identifier.dirConflictPolicyPicker
        case .FilePolicy:
            return NSToolbarItem.Identifier.fileConflictPolicyPicker
        }
    }

    func getToolbarItemGroupForPickerItemIdentifier(_ pickerItemIdentifier: PickerItemIdentifier) -> NSToolbarItemGroup? {
        assert(self.items.count > 0, "No items in toolbar!")
        let gnstiid = MainWindowToolbar.getGroupNSTIIDFromPickerItemIdentifier(pickerItemIdentifier)

        for item in self.items {
            if item.itemIdentifier == gnstiid {
                if let itemGroup = item as? NSToolbarItemGroup {
                    return itemGroup
                } else {
                    NSLog("ERROR PickerItemIdentifier does not resolve to a NSToolbarItemGroup: \(item.itemIdentifier) (found: \(type(of: item))")
                    return nil
                }
            }
        }
        return nil
    }

    private static func indexForPickerItemIdentifier(_ pickerItemIdentifier: PickerItemIdentifier) -> Int? {
        var index = 0
        let nstiid = self.getGroupNSTIIDFromPickerItemIdentifier(pickerItemIdentifier)
        for pickerGroup in self.getPickerGroupForNSTIID(nstiid).itemList {
            if pickerGroup.identifier == pickerItemIdentifier {
                return index
            }
            index += 1
        }
        return nil
    }

    static func getPickerItemIdentifierFromIndex(_ selectedIndex: Int, _ groupIdentifier: NSToolbarItem.Identifier) throws -> PickerItemIdentifier? {
        let pickerList = MainWindowToolbar.getPickerGroupForNSTIID(groupIdentifier).itemList
        guard selectedIndex < pickerList.count else {
            throw OutletError.invalidArgument("Index \(selectedIndex) is invalid for group \(groupIdentifier)")
        }
        return pickerList[selectedIndex].identifier
    }

    // --------------------------------------------------------------------------------------------

    /**
    Called when a user clicks on a picker in the toolbar
   */
    @objc func toolbarPickerDidSelectItem(_ sender: NSToolbarItemGroup) {
        let app: OutletMacApp = NSApplication.shared.delegate as! OutletMacApp
        NSLog("DEBUG [\(ID_APP)] toolbarPickerDidSelectItem() entered: identifier = \(sender.itemIdentifier)")

        let newItemIdentifier: PickerItemIdentifier
        do {
            guard let val = try MainWindowToolbar.getPickerItemIdentifierFromIndex(sender.selectedIndex, sender.itemIdentifier) else {
                return
            }
            newItemIdentifier = val
        } catch OutletError.invalidArgument {
            app.reportError("Could not select option", "Invalid toolbar index: \(sender.selectedIndex)")
            return
        } catch {
            app.reportError("Could not select option", "Unexpected error: \(error)")
            return
        }

        NSLog("DEBUG [\(ID_APP)] toolbarPickerDidSelectItem(): Resolved index \(sender.selectedIndex) -> identifier \(newItemIdentifier)")
        app.changePickerItem(newItemIdentifier)
    }

}
