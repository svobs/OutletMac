//
// Created by Matthew Svoboda on 21/9/11.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa

/**
 Official Apple docs: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/MenuList.html
 This is awesome: https://medium.com/@theboi/macos-apps-without-storyboard-or-xib-menu-bar-in-swift-5-menubar-and-toolbar-6f6f2fa39ccb
 */
class AppMainMenu: NSMenu {
    // App-wide actions:
    // TODO: find a better place for these
    public static let DIFF_TREES_BY_CONTENT: Selector = #selector(OutletMacApp.diffTreesByContent)
    public static let MERGE_CHANGES: Selector = #selector(OutletMacApp.mergeDiffChanges)
    public static let CANCEL_DIFF: Selector = #selector(OutletMacApp.cancelDiff)

    override init(title: String) {
        super.init(title: title)

        self.items = AppMainMenu.buildMainMenu()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    private static func buildMainMenu() -> [NSMenuItem] {
        return [
            buildAppMenu(), buildEditMenu(), buildToolsMenu(), buildViewMenu(), buildWindowMenu()
        ]

    }

    /*
     Application Menu
     */
    private static func buildAppMenu() -> NSMenuItem {
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

    /*
     Edit Menu
     */
    private static func buildEditMenu() -> NSMenuItem {
        let editMenu = NSMenuItem()
        editMenu.title = "Edit"
        editMenu.submenu = NSMenu(title: "Edit")

        let delete = NSMenuItem(title: "Delete", action: nil, keyEquivalent: "⌫")
        delete.keyEquivalentModifierMask.remove(.command)

        let app: OutletAppProtocol = NSApplication.shared.delegate as! OutletAppProtocol

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
//            buildDragModeSubmenu(app),
            ]

        return editMenu
    }

    private static func buildDragModeSubmenu(_ app: OutletAppProtocol) -> NSMenuItem {
        let group = ToolStateSpace.dragModeGroup

//        let groupMenuMeta: MenuItemMeta = group.toMenuMeta()
        // TODO!

        let submenu = NSMenuItem()
        submenu.title = group.groupLabel
        submenu.submenu = NSMenu(title: group.groupLabel)


//        for item in group.itemList {
//            let menuItem = NSMenuItem(title: item.title, action: #selector(OutletMacApp.changeDragMode(<#T##OutletMacApp##OutletMac.OutletMacApp#>)), keyEquivalent: "")
//            menuItem.toolTip = item.toolTip
//            submenu.submenu?.items.append(menuItem)
//        }

        return submenu
    }

    private static func buildToolsMenu() -> NSMenuItem {
        let toolsMenu = NSMenuItem()
        toolsMenu.submenu = NSMenu(title: "Tools")

        toolsMenu.submenu?.items = [
            NSMenuItem(title: "Diff Trees By Content", action: #selector(OutletMacApp.diffTreesByContent), keyEquivalent: "d"),
        ]
        return toolsMenu
    }

    private static func buildViewMenu() -> NSMenuItem {
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

    private static func buildWindowMenu() -> NSMenuItem {
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
