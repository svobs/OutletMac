//
// Created by Matthew Svoboda on 21/9/8.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

/**
 Abstract base class
 */
class AppWindow: NSWindow, NSWindowDelegate, HasLifecycle {
    let app: OutletApp
    var dispatchListener: DispatchListener! = nil
    private var windowIsOpen = true

    func windowWillClose(_ notification: Notification) {
        NSLog("DEBUG [\(self.winID)] windowWillClose() entered")
        windowIsOpen = false

        do {
            try self.shutdown()
        } catch {
            NSLog("ERROR Failure during parentWindow close: \(error)")
        }
    }

    var isOpen: Bool {
        get {
            return self.windowIsOpen
        }
    }

    var winID: String {
        get {
            fatalError("Cannot call 'winID' method of AppWindow base class!")
        }
    }

    init(_ app: OutletApp, _ contentRect: NSRect, styleMask style: NSWindow.StyleMask) {
        self.app = app

        // TODO: save content rect in config
        // note: x & y are from lower-left corner
        super.init(
                contentRect: contentRect,
                styleMask: style,
                backing: .buffered, defer: false)
        // this will override x & y from content rect

    }

    func start() throws {
        NSLog("DEBUG [\(self.winID)] Starting")
        self.dispatchListener = self.app.dispatcher.createListener("\(self.winID)-dialog")

        // Enables windowWillClose() callback
        self.delegate = self
    }

    // This is called by windowWillClose()
    func shutdown() throws {
        NSLog("DEBUG [\(self.winID)] Window shutdown() called")
        self.dispatchListener.unsubscribeAll()
    }

    func showWindow() {
        NSLog("DEBUG [\(self.winID)] showWindow() called")
        self.makeKeyAndOrderFront(nil)
        self.windowIsOpen = true
    }

    /**
     NSWindow method
     */
    override func keyDown(with event: NSEvent) {
        // Pass all key events to the project model
        NSLog("DEBUG [\(self.winID)] KEY EVENT: \(event)")
        // Enable key events
        interpretKeyEvents([event])
        if event.keyCode == 13 {
            NSLog("DEBUG [\(self.winID)] ENTER KEY PRESSED!")
        } else {
            NSLog("DEBUG [\(self.winID)] User pressed key: \(event.keyCode)")
        }
    }

}
