//
// Created by Matthew Svoboda on 21/9/11.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa
import OutletCommon

/**
 Official Apple docs: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/MenuList.html
 This is awesome: https://medium.com/@theboi/macos-apps-without-storyboard-or-xib-menu-bar-in-swift-5-menubar-and-toolbar-6f6f2fa39ccb
 */
class AppMainMenu: NSMenu {
    var app: OutletMacApp!

    override init(title: String) {
        super.init(title: title)
        self.autoenablesItems = true
    }

    func buildMainMenu(_ app: OutletMacApp) {
        self.app = app

        self.items = [
            buildAppMenu(), buildEditMenu(), buildToolsMenu(), buildViewMenu(), buildWindowMenu()
        ]
    }

    // Why does AppKit need this?? So annoying.
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Callback
    override func itemChanged(_ item: NSMenuItem) {
        NSLog("WARNING [\(ID_APP)] ITEM CHANGED: \(item)")
        super.itemChanged(item)
    }

    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        NSLog("WARNING [AppMainMenu] Entered validateMenuItem() for item \(item)'")
        return true
    }

    /**
     Application Menu
     */
    private func buildAppMenu() -> NSMenuItem {
        let appMenu = NSMenuItem()
        appMenu.submenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.submenu?.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.submenu?.addItem(NSMenuItem.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        services.submenu =  NSMenu()
        appMenu.submenu?.addItem(services)
        appMenu.submenu?.addItem(NSMenuItem.separator())
        appMenu.submenu?.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.submenu?.addItem(hideOthers)
        appMenu.submenu?.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.submenu?.addItem(NSMenuItem.separator())
        appMenu.submenu?.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return appMenu
    }

    /**
     Edit Menu
     */
    private func buildEditMenu() -> NSMenuItem {
        let editMenu = NSMenuItem()
        editMenu.title = "Edit"
        editMenu.submenu = NSMenu(title: "Edit")

        let delete = NSMenuItem(title: "Delete", action: nil, keyEquivalent: "⌫")
        delete.keyEquivalentModifierMask.remove(.command)

        editMenu.submenu?.items = [
            NSMenuItem(title: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z"),
            NSMenuItem(title: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z"),
            NSMenuItem.separator(),
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            delete,
            NSMenuItem.separator(),
            NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
            NSMenuItem.separator(),
            buildToolPickerGroupSubmenu(ToolStateSpace.dragModeGroup),
            buildToolPickerGroupSubmenu(ToolStateSpace.dirConflictPolicyGroup),
            buildToolPickerGroupSubmenu(ToolStateSpace.fileConflictPolicyGroup)
            ]

        return editMenu
    }

    /**
     Edit Menu: submenu for a single tool picker group
     */
    private func buildToolPickerGroupSubmenu(_ group: PickerGroup) -> NSMenuItem {
        let submenu = NSMenuItem()
        submenu.title = group.groupLabel
        submenu.submenu = NSMenu(title: group.groupLabel)

        for item in group.itemList {
            NSLog("DEBUG Adding ToolbarPicker menu item: \(item.identifier)")
            // NOTE: for validation & checkmarks, see GlobalActions.validateMenuItem() (since apparently the class of the selector is responsible)
            let menuItem = GeneratedMenuItem(item.toMenuItemMeta(), action: #selector(GlobalActions.executeGlobalMenuAction(_:)))
            menuItem.toolTip = item.toolTip
            menuItem.target = self.app.globalActions   // This MUST match the action class (I think) or else silent failure
            submenu.submenu?.items.append(menuItem)
        }

        return submenu
    }

    /**
     Tools Menu
     */
    private func buildToolsMenu() -> NSMenuItem {
        let toolsMenu = NSMenuItem()
        toolsMenu.submenu = NSMenu(title: "Tools")

        let diffItem = GeneratedMenuItem(MenuItemMeta(itemType: .NORMAL, title: "Diff Trees By Content", actionType: .BUILTIN(.DIFF_TREES_BY_CONTENT)),
                action: #selector(GlobalActions.executeGlobalMenuAction(_:)))
        diffItem.keyEquivalent = "d"
        diffItem.target = self.app.globalActions   // This MUST match the action class (I think) or else silent failure
        toolsMenu.submenu?.items.append(diffItem)

        toolsMenu.submenu?.items.append(GeneratedMenuItem(MenuItemMeta(itemType: .NORMAL, title: "Merge Changes", actionType: .BUILTIN(.MERGE_CHANGES)),
                action: #selector(GlobalActions.executeGlobalMenuAction(_:))))

        return toolsMenu
    }

    /**
     View Menu
     */
    private func buildViewMenu() -> NSMenuItem {
        let viewMenu = NSMenuItem()
        viewMenu.submenu = NSMenu(title: "View")

        let showToolbar = NSMenuItem(title: "Show Toolbar", action: #selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent: "t")
        showToolbar.keyEquivalentModifierMask = .command.union(.option)

        let toggleFullScreen =
                NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        toggleFullScreen.keyEquivalentModifierMask = .command.union(.control)  // same as Google Chrome

        viewMenu.submenu?.items = [
            showToolbar,
            NSMenuItem.separator(),
            toggleFullScreen,
    ]
        return viewMenu
    }

    /**
     Window Menu
     */
    private func buildWindowMenu() -> NSMenuItem {
        let windowMenu = NSMenuItem()
        windowMenu.submenu = NSMenu(title: "Window")
        windowMenu.submenu?.items = [
            NSMenuItem(title: "Minmize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"),
            NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""),
            NSMenuItem.separator(),
            NSMenuItem(title: "Show All", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "m")
        ]
        return windowMenu
    }
}
