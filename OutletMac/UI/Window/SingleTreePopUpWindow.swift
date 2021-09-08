//
// Created by Matthew Svoboda on 21/5/10.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class SingleTreePopUpWindow: AppWindow, ObservableObject {
    let con: TreePanelControllable
    let initialSelection: SPIDNodePair?

    override var winID: String {
        get {
            self.con.treeID
        }
    }

    init(_ app: OutletApp, _ con: TreePanelControllable, initialSelection: SPIDNodePair?) {
        self.con = con
        self.initialSelection = initialSelection
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        super.init(app, contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
    }

    override func start() throws {
        self.dispatchListener.subscribe(signal: .TREE_LOAD_STATE_UPDATED, self.onTreeLoadStateUpdated, whitelistSenderID: self.winID)
        self.dispatchListener.subscribe(signal: .POPULATE_UI_TREE_DONE, self.onPopulateTreeDone, whitelistSenderID: self.winID)
        self.dispatchListener.subscribe(signal: .TREE_SELECTION_CHANGED, self.onSelectionChanged, whitelistSenderID: self.winID)

        // TODO: create & populate progress bar to show user that something is being done here

        try self.con.requestTreeLoad()
    }

    // This is called by windowWillClose()
    override func shutdown() throws {
        try super.shutdown()
        try self.con.shutdown()
    }

    func selectSPID(_ spid: SPID) {
        // If successful, this should fire the selection listener, which will result in onSelectionChanged() below
        // being hit
        self.con.treeView!.selectSingleGUID(spid.guid)
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
                self.showWindow()
            }
        default:
            break
        }
    }

    // This will be triggered by the tree panel controller
    func onPopulateTreeDone(_ senderID: SenderID, _ props: PropDict) throws {
        DispatchQueue.main.async {
            self.showWindow()

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
