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

    init(_ app: OutletApp, _ backendConnectionState: BackendConnectionState) {
        self.app = app

        // TODO: save content rect in config
        // note: x & y are from lower-left corner
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 200)
        window = ConnectionProblemWindow(
                contentRect: contentRect,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
        self.window.center()
        self.window.title = "Connection to Agent Failed"

        let content = ConnectionProblemContent(self.app, self.window, backendConnectionState)
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
    @ObservedObject var backendConnectionState: BackendConnectionState
    var parentWindow: NSWindow
    let app: OutletApp

    init(_ app: OutletApp, _ parentWindow: NSWindow, _ backendConnectionState: BackendConnectionState) {
        self.parentWindow = parentWindow
        self.app = app
        self.backendConnectionState = backendConnectionState
    }

    func quitButtonClicked() {
        NSLog("DEBUG ConnectionProblemContent: Quit btn clicked!'")
        self.parentWindow.close()
        do {
            try self.app.shutdown()
        } catch {
            // this shouldn't happen in principle
            NSLog("ERROR Failure during shutdown: \(error)")
        }
    }

    func relaunchButtonClicked() {
        NSLog("DEBUG ConnectionProblemContent: Relaunch btn clicked!'")
        self.backendConnectionState.isRelaunching = true

        // TODO
    }

    var body: some View {
        VStack {
            Text("Trying to connect to \(backendConnectionState.host), port \(String(backendConnectionState.port))")

            Text("Attempting retry #\(backendConnectionState.conecutiveStreamFailCount)...")

            HStack {
                Button("Kill & relaunch agent", action: self.relaunchButtonClicked)
                        .keyboardShortcut(.defaultAction)  // this will also color the button
                        .disabled(self.backendConnectionState.isRelaunching)

                Button("Quit", action: self.quitButtonClicked)
                        .keyboardShortcut(.cancelAction)
            }.frame(alignment: .center)
                    .padding(.bottom).padding(.horizontal)  // we have enough padding above already
        }.frame(width: 300, height: 100)  // set minimum window dimensions
    }

}
