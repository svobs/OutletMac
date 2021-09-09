//
// Created by Matthew Svoboda on 21/5/24.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class ConnectionProblemWindow: AppWindow, ObservableObject {
    init(_ app: OutletApp, _ backendConnectionState: BackendConnectionState) {
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 200)
        super.init(app, contentRect, styleMask: [.titled, .closable, .fullSizeContentView])
        self.center()
        self.title = "Connection to Agent Failed"

        let content = ConnectionProblemContent(self.app, self, backendConnectionState)
        self.contentView = NSHostingView(rootView: content)
    }

    override var winID: String {
        get {
            "ConnectionProblemWindow"
        }
    }
}

struct ConnectionProblemContent: View {
    @ObservedObject var backendConnectionState: BackendConnectionState
    weak var parentWindow: ConnectionProblemWindow!
    weak var app: OutletApp!

    init(_ app: OutletApp, _ parentWindow: ConnectionProblemWindow, _ backendConnectionState: BackendConnectionState) {
        self.parentWindow = parentWindow
        self.app = app
        self.backendConnectionState = backendConnectionState
    }

    func quitButtonClicked() {
        NSLog("DEBUG [\(self.parentWindow.winID)]: Quit btn clicked!")
        self.parentWindow.close()
        do {
            try self.app.shutdown()
        } catch {
            // this shouldn't happen in principle
            NSLog("ERROR Failure during app shutdown: \(error)")
        }
    }

    func relaunchButtonClicked() {
        NSLog("DEBUG ConnectionProblemContent: Relaunch btn clicked!'")
        self.backendConnectionState.isRelaunching = true

        // TODO
    }

    var body: some View {
        // TODO: show if we are using Bonjour instead: "Looking for service..."
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
        }.frame(width: 300, height: 100)  // set minimum parentWindow dimensions
    }

}
