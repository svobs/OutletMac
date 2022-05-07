//
// Created by Matthew Svoboda on 21/9/8.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI
import OutletCommon

/**
 Abstract base class
 */
class AppWindow: NSWindow, NSWindowDelegate, HasLifecycle {
    weak var app: OutletAppProtocol!
    var dispatchListener: DispatchListener! = nil
    private var windowIsOpen = true

    override func close() {
        NSLog("DEBUG [\(self.winID)] close() entered")
        super.close()
    }

    // This only gets triggered if the OS ACTUALLY is closing the window, even if close() is called extraneously
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

    init(_ app: OutletAppProtocol, _ contentRect: NSRect, styleMask style: NSWindow.StyleMask) {
        self.app = app

        // TODO: save content rect in config
        // note: x & y are from lower-left corner
        super.init(
                contentRect: contentRect,
                styleMask: style,
                backing: .buffered, defer: true)
        // this will override x & y from content rect

    }

    func start() throws {
        NSLog("DEBUG [\(self.winID)] Starting")
        self.dispatchListener = self.app.dispatcher.createListener(self.winID)

        // Enables windowWillClose() callback
        self.delegate = self
    }

    /**
     This is called by windowWillClose()
     */
    func shutdown() throws {
        NSLog("DEBUG [\(self.winID)] shutdown() called")
        self.dispatchListener!.unsubscribeAll()
    }

    func showWindow() {
        NSLog("DEBUG [\(self.winID)] showWindow() called")
        assert(DispatchQueue.isExecutingIn(.main))
        self.makeKeyAndOrderFront(nil)
        self.windowIsOpen = true
    }

    /**
     NSWindow method
     */
    override func keyDown(with event: NSEvent) {
        // Pass all key events to the project model
        NSLog("DEBUG [\(self.winID)] KEY EVENT: \(event)")
        super.keyDown(with: event)
        // Enable key events
        interpretKeyEvents([event])
        if event.keyCode == 13 {
            NSLog("DEBUG [\(self.winID)] Enter key pressed!")
        } else if event.keyCode == 53 {
            NSLog("DEBUG [\(self.winID)] Escape key pressed!")
            self.app.dispatcher.sendSignal(signal: .CANCEL_ALL_EDIT_ROOT, senderID: self.winID)
        } else {
            NSLog("DEBUG [\(self.winID)] User pressed key: \(event.keyCode)")
        }
    }

}
