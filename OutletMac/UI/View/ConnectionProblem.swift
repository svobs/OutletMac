//
// Created by Matthew Svoboda on 21/5/24.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class ConnectionProblemWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        // Pass all key events to the project model
        NSLog("KEY EVENT: \(event)")
        // Enable key events
        interpretKeyEvents([event])
        if event.keyCode == 13 {
            NSLog("ENTER KEY PRESSED!")
        } else {
            NSLog("User pressed key: \(event.keyCode)")
        }
    }
}

class ConnectionProblemView: NSObject, NSWindowDelegate, HasLifecycle, ObservableObject {
    let app: OutletApp
    var window: ConnectionProblemWindow!
    private var windowIsOpen = true

    func windowWillClose(_ notification: Notification) {
        windowIsOpen = false

        do {
            try self.shutdown()
        } catch {
            NSLog("ERROR Failure during window close; \(error)")
        }
    }

    var isOpen: Bool {
        get {
            return self.windowIsOpen
        }
    }

    init(_ app: OutletApp) {
        self.app = app

        // TODO: save content rect in config
        // note: x & y are from lower-left corner
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = ConnectionProblemWindow(
                contentRect: contentRect,
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
        self.window.center()
        self.window.title = "Cannot connect to agent"

        let content = ConnectionProblemContent(self.app, self.window)
        window.contentView = NSHostingView(rootView: content)
    }

    func start() throws {
        // Enables windowWillClose() callback
        window.delegate = self
    }

    // This is called by windowWillClose()
    func shutdown() throws {
        NSLog("DEBUG ConnectionProblemWindow shutdown() called")
    }

    func moveToFront() {
        DispatchQueue.main.async {
            self.window.makeKeyAndOrderFront(nil)
        }
    }
}

struct ConnectionProblemContent: View {
    @StateObject var heightTracking: HeightTracking = HeightTracking()
    var parentWindow: NSWindow
    let app: OutletApp

    init(_ app: OutletApp, _ parentWindow: NSWindow) {
        self.parentWindow = parentWindow
        self.app = app
    }

    func okClicked() {
        // TODO
        NSLog("DEBUG OK btn clicked!'")
        self.parentWindow.close()
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Cancel", action: {
                    NSLog("DEBUG ConnectionProblemContent: Cancel button was clicked")
                    self.parentWindow.close()
                })
                        .keyboardShortcut(.cancelAction)
                Button("Proceed", action: self.okClicked)
                        .keyboardShortcut(.defaultAction)  // this will also color the button
            }
                    .padding(.bottom).padding(.horizontal)  // we have enough padding above already
        }.frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)  // set minimum window dimensions
    }

}
