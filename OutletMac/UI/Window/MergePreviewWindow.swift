//
// Created by Matthew Svoboda on 21/5/10.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

/**
 Container class for all GDrive root chooser dialog data. Actual view starts with GDriveRootChooserContent
 */
class MergePreviewWindow: SingleTreePopUpWindow {
    override init(_ app: OutletApp, _ con: TreePanelControllable, initialSelection: SPIDNodePair? = nil) {
        super.init(app, con, initialSelection: initialSelection)
        assert(con.treeID == ID_MERGE_TREE)
        self.center()
        self.title = "Confirm Merge"

        let content = MergePreviewContent(self)
                .environmentObject(self.app.globalState)
        self.contentView = NSHostingView(rootView: content)
    }

}

/**
 The content area of the Merge Preview dialog.
 */
struct MergePreviewContent: View {
    @StateObject var windowState: WindowState = WindowState()
    weak var parentWindow: SingleTreePopUpWindow!

    init(_ parentWindow: SingleTreePopUpWindow) {
        self.parentWindow = parentWindow
    }

    func doMerge() {
        NSLog("DEBUG [\(self.parentWindow.winID)] OK btn clicked! Sending signal: '\(Signal.COMPLETE_MERGE)'")
        self.parentWindow.con.dispatcher.sendSignal(signal: .COMPLETE_MERGE, senderID: ID_MERGE_TREE)

        // BE will notify the app on success or failure, and it will decide whether to close this window.
    }

    var body: some View {
        VStack {
            GeometryReader { geo in
                SinglePaneView(self.parentWindow.app, self.parentWindow.con, self.windowState)
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
                    NSLog("DEBUG [\(self.parentWindow.winID)] Cancel button was clicked")
                    self.parentWindow.app.sendEnableUISignal(enable: true)
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
