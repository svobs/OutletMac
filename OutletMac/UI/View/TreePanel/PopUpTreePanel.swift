//
// Created by Matthew Svoboda on 21/5/10.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class PopUpTreePanelWindow: NSWindow {
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

class PopUpTreePanel: NSObject, NSWindowDelegate, HasLifecycle, ObservableObject {
    let app: OutletApp
    let con: TreePanelControllable
    let dispatchListener: DispatchListener

    private var windowIsOpen = true
    private var loadComplete: Bool = false
    var window: NSWindow!
    let initialSelection: SPIDNodePair?

    func windowWillClose(_ notification: Notification) {
        NSLog("DEBUG [\(self.con.treeID)] windowWillClose() entered")
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

    init(_ app: OutletApp, _ con: TreePanelControllable, initialSelection: SPIDNodePair?) {
        self.app = app
        self.con = con
        self.initialSelection = initialSelection
        self.dispatchListener = self.app.dispatcher.createListener("\(self.con.treeID))-dialog")

        // TODO: save content rect in config
        // note: x & y are from lower-left corner
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = PopUpTreePanelWindow(
                contentRect: contentRect,
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
        // this will override x & y from content rect

    }

    func start() throws {
        // Enables windowWillClose() callback
        window.delegate = self

        try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_DONE, self.onLoadSubtreeDone, whitelistSenderID: self.con.treeID)
        try self.dispatchListener.subscribe(signal: .POPULATE_UI_TREE_DONE, self.onPopulateTreeDone, whitelistSenderID: self.con.treeID)
        try self.dispatchListener.subscribe(signal: .TREE_SELECTION_CHANGED, self.onSelectionChanged, whitelistSenderID: self.con.treeID)

        // TODO: create & populate progress bar to show user that something is being done here

        try self.con.requestTreeLoad()
    }

    // This is called by windowWillClose()
    func shutdown() throws {
        NSLog("DEBUG [\(self.con.treeID)] Window shutdown() called")
        try self.con.shutdown()
        try self.dispatchListener.unsubscribeAll()
    }

    func selectSPID(_ spid: SPID) {
        // If successful, this should fire the selection listener, which will result in onSelectionChanged() below
        // being hit
        self.con.treeView!.selectSingleSPID(spid)
    }

    func moveToFront() {
        if loadComplete {
            DispatchQueue.main.async {
                self.window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // DispatchListener callbacks
    // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

    func onLoadSubtreeDone(_ senderID: SenderID, _ props: PropDict) throws {
        NSLog("DEBUG [\(self.con.treeID)] Backend load complete. Showing dialog")
        self.loadComplete = true
        self.moveToFront()
    }

    func onPopulateTreeDone(_ senderID: SenderID, _ props: PropDict) throws {
        if let selectionSPID = self.initialSelection?.spid {
            NSLog("DEBUG [\(self.con.treeID)] Populate complete! Selecting SPID: \(selectionSPID)")
            DispatchQueue.main.async {
                self.selectSPID(selectionSPID)
            }
        }
    }

    func onSelectionChanged(_ senderID: SenderID, _ props: PropDict) throws {
        // default to nothing
    }

}
