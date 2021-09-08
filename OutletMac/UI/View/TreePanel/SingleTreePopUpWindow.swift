//
// Created by Matthew Svoboda on 21/5/10.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class SingleTreePopUpWindow: NSWindow, NSWindowDelegate, HasLifecycle, ObservableObject {
    let app: OutletApp
    let con: TreePanelControllable
    let dispatchListener: DispatchListener

    private var windowIsOpen = true
    let initialSelection: SPIDNodePair?

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
            self.con.treeID
        }
    }

    init(_ app: OutletApp, _ con: TreePanelControllable, initialSelection: SPIDNodePair?) {
        self.app = app
        self.con = con
        self.initialSelection = initialSelection
        self.dispatchListener = self.app.dispatcher.createListener("\(con.treeID)-dialog")

        // TODO: save content rect in config
        // note: x & y are from lower-left corner
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        super.init(
                contentRect: contentRect,
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
        // this will override x & y from content rect

    }

    func start() throws {
        // Enables windowWillClose() callback
        self.delegate = self

        self.dispatchListener.subscribe(signal: .TREE_LOAD_STATE_UPDATED, self.onTreeLoadStateUpdated, whitelistSenderID: self.winID)
        self.dispatchListener.subscribe(signal: .POPULATE_UI_TREE_DONE, self.onPopulateTreeDone, whitelistSenderID: self.winID)
        self.dispatchListener.subscribe(signal: .TREE_SELECTION_CHANGED, self.onSelectionChanged, whitelistSenderID: self.winID)

        // TODO: create & populate progress bar to show user that something is being done here

        try self.con.requestTreeLoad()
    }

    // This is called by windowWillClose()
    func shutdown() throws {
        NSLog("DEBUG [\(self.winID)] Window shutdown() called")
        try self.con.shutdown()
        self.dispatchListener.unsubscribeAll()
    }

    func selectSPID(_ spid: SPID) {
        // If successful, this should fire the selection listener, which will result in onSelectionChanged() below
        // being hit
        self.con.treeView!.selectSingleSPID(spid)
    }

    func moveToFront() {
        NSLog("DEBUG [\(self.winID)] moveToFront() called")
        self.makeKeyAndOrderFront(nil)
        self.windowIsOpen = true
    }

    /**
     NSWindow method
     */
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

    // DispatchListener callbacks
    // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

    private func onTreeLoadStateUpdated(_ senderID: SenderID, _ propDict: PropDict) throws {
        let treeLoadState = try propDict.get("tree_load_state") as! TreeLoadState
        NSLog("DEBUG [\(self.winID)] SingleTreePopUpWindow: Got signal \(Signal.TREE_LOAD_STATE_UPDATED) with tree_load_state=\(treeLoadState)")

        switch treeLoadState {
        case .COMPLETELY_LOADED:
            // note: around exactly the same time, the TreePanelController will receive this and start populating
            DispatchQueue.main.async {
                NSLog("DEBUG [\(self.winID)] Backend load complete. Showing dialog")
                self.moveToFront()
            }
        default:
            break
        }
    }

    // This will be triggered by the tree panel controller
    func onPopulateTreeDone(_ senderID: SenderID, _ props: PropDict) throws {
        DispatchQueue.main.async {
            self.moveToFront()

            if let selectionSPID = self.initialSelection?.spid {
                NSLog("DEBUG [\(self.winID)] Populate complete! Selecting SPID: \(selectionSPID)")
                self.selectSPID(selectionSPID)
            }
        }
    }

    func onSelectionChanged(_ senderID: SenderID, _ props: PropDict) throws {
        // default to nothing
    }

}
