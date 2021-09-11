//
// Created by Matthew Svoboda on 21/9/11.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Cocoa

// This is awesome: https://medium.com/@theboi/macos-apps-without-storyboard-or-xib-menu-bar-in-swift-5-menubar-and-toolbar-6f6f2fa39ccb
class AppMainMenu: NSMenu {
    override init(title: String) {
        super.init(title: title)

        self.items = AppMainMenu.buildMainMenu()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    private static func buildMainMenu() -> [NSMenuItem] {
        return [buildAppMenu(), buildEditMenu()]

    }

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

    private static func buildEditMenu() -> NSMenuItem {
        let editMenu = NSMenuItem()
        editMenu.title = "Edit"
        editMenu.submenu = NSMenu(title: "Edit")
        return editMenu
    }
}
