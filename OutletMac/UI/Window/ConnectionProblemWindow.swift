//
// Created by Matthew Svoboda on 21/5/24.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class ConnectionProblemWindow: AppWindow, ObservableObject {
    init(_ app: OutletAppProtocol, _ backendConnectionState: BackendConnectionState) {
        NSLog("DEBUG [ConnectionProblemWindow] Init")
        self.backendConnectionState = backendConnectionState
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 200)
        super.init(app, contentRect, styleMask: [.titled, .closable, .fullSizeContentView])
        self.isReleasedWhenClosed = false  // make it reusable
        self.title = "Connection to Agent Failed"
        self.center()

        NSLog("DEBUG [ConnectionProblemWindow] Init done")
    }

    private var backendConnectionState: BackendConnectionState

    override var winID: String {
        get {
            "ConnectionProblemWindow"
        }
    }

    override func start() throws {
        try super.start()  // this creates the dispatchListener

        let content = ConnectionProblemContent(self.app, self).environmentObject(self.backendConnectionState)
        // FIXME: it doesn't seem to be happy something here:
        self.contentView = NSHostingView(rootView: content)
        NSLog("DEBUG [\(self.winID)] Start done")
    }

}

struct ConnectionProblemContent: View {
    @EnvironmentObject var backendConnectionState: BackendConnectionState
    weak var parentWindow: ConnectionProblemWindow!
    weak var app: OutletAppProtocol!

    init(_ app: OutletAppProtocol, _ parentWindow: ConnectionProblemWindow) {
        self.parentWindow = parentWindow
        self.app = app
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
        // TODO: show if we are using LegacyBonjourBrowser instead: "Looking for service..."
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
