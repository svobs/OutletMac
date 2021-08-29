//
// Created by Matthew Svoboda on 21/5/10.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

/**
 The content area of the Merge Preview dialog.
 */
struct MergePreviewContent: View {
    @StateObject var windowState: WindowState = WindowState()
    var parentWindow: NSWindow
    let app: OutletApp
    let con: TreePanelControllable

    init(_ app: OutletApp, _ con: TreePanelControllable, _ parentWindow: NSWindow) {
        self.parentWindow = parentWindow
        self.app = app
        self.con = con
    }

    func doMerge() {
        NSLog("DEBUG OK btn clicked! Sending signal: '\(Signal.COMPLETE_MERGE)'")
        self.con.dispatcher.sendSignal(signal: .COMPLETE_MERGE, senderID: ID_MERGE_TREE)
        self.parentWindow.close()
    }

    var body: some View {
        VStack {
            GeometryReader { geo in
                SinglePaneView(self.app, self.con, self.windowState)
                        .environmentObject(self.app.settings)
                        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle()) // taps should be detected in the whole window
                        .preference(key: ContentAreaPrefKey.self, value: ContentAreaPrefData(height: geo.size.height))
                        .onPreferenceChange(ContentAreaPrefKey.self) { key in
//                            NSLog("HEIGHT OF WINDOW CANVAS: \(key.height)")
                            self.windowState.windowHeight = key.height
                        }
            }
            HStack {
                Spacer()
                Button("Cancel", action: {
                    NSLog("DEBUG [\(self.con.treeID)] Cancel button was clicked")
                    self.parentWindow.close()
                })
                        .keyboardShortcut(.cancelAction)
                Button("Proceed", action: self.doMerge)
                        .keyboardShortcut(.defaultAction)  // this will also color the button
            }
                    .padding(.bottom).padding(.horizontal)  // we have enough padding above already
        }.frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)  // set minimum window dimensions
    }

}

/**
 Container class for all GDrive root chooser dialog data. Actual view starts with GDriveRootChooserContent
 */
class MergePreview: PopUpTreePanel {

    override init(_ app: OutletApp, _ con: TreePanelControllable, initialSelection: SPIDNodePair? = nil) {
        super.init(app, con, initialSelection: initialSelection)
        assert(con.treeID == ID_MERGE_TREE)
        self.window.center()
        self.window.title = "Confirm Merge"

        let content = MergePreviewContent(self.app, self.con, self.window)
        window.contentView = NSHostingView(rootView: content)
    }

}
