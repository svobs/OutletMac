//
// Created by Matthew Svoboda on 21/5/10.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class SingleTreePopUpWindow: AppWindow, ObservableObject {
    private let _winID: String
    weak var con: TreeControllable? = nil
    var initialSelection: SPIDNodePair? = nil

    override var winID: String {
        get {
            _winID
        }
    }

    init(_ app: OutletAppProtocol, treeID: TreeID) {
        self._winID = "\(treeID)-window"
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        super.init(app, contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
    }

    func setController(_ con: TreeControllable, initialSelection: SPIDNodePair? = nil) {
        NSLog("DEBUG [\(self.winID)] setController() entered")
        self.con = con
        self.initialSelection = initialSelection
    }

    override func start() throws {
        guard let _ = self.con else {
            throw OutletError.invalidState("Controller not set!")
        }
        try super.start()

        // Add extra listeners to some of the controller's signals
        self.dispatchListener.subscribe(signal: .TREE_LOAD_STATE_UPDATED, self.onTreeLoadStateUpdated, whitelistSenderID: self.con!.treeID)
        self.dispatchListener.subscribe(signal: .POPULATE_UI_TREE_DONE, self.onPopulateTreeDone, whitelistSenderID: self.con!.treeID)
        self.dispatchListener.subscribe(signal: .TREE_SELECTION_CHANGED, self.onSelectionChanged, whitelistSenderID: self.con!.treeID)

        // TODO: create & populate progress bar to show user that something is being done here

        try self.con!.requestTreeLoad()
        NSLog("DEBUG [\(self.winID)] Start done")
    }

    // This is called by windowWillClose()
    override func shutdown() throws {
        NSLog("DEBUG [\(self.winID)] shutdown() starting")
        try super.shutdown()
        try self.con?.shutdown()
        NSLog("DEBUG [\(self.winID)] shutdown() done")
    }

    func selectSPID(_ spid: SPID) {
        // If successful, this should fire the selection listener, which will result in onSelectionChanged() below
        // being hit
        NSLog("DEBUG [\(self.winID)] Selecting GUID: \(spid.guid)")
        self.con?.treeView!.selectSingleGUID(spid.guid, scrollToSelection: true)
    }

    // DispatchListener callbacks
    // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

    private func onTreeLoadStateUpdated(_ senderID: SenderID, _ propDict: PropDict) throws {
        let treeLoadState = try propDict.get("tree_load_state") as! TreeLoadState
        NSLog("DEBUG [\(self.winID)] SingleTreePopUpWindow: Got signal \(Signal.TREE_LOAD_STATE_UPDATED) with tree_load_state=\(treeLoadState)")

        switch treeLoadState {
        case .COMPLETELY_LOADED:
            // note: around exactly the same time, the TreeController will also receive this and start populating.
            // We'll wait for its POPULATE_UI_TREE_DONE signal before showing the window
            NSLog("DEBUG [\(self.winID)] Backend load complete")
        default:
            break
        }
    }

    // This will be triggered by the tree panel controller
    func onPopulateTreeDone(_ senderID: SenderID, _ props: PropDict) throws {
        if let selectionSPID = self.initialSelection?.spid {
            // TODO: put all this logic in the backend, let it update the expanded row set and push it out like other trees
            NSLog("DEBUG [\(self.winID)] Attempting to select SPID: \(selectionSPID)")
            do {
                let ancestorList: [SPIDNodePair] = try self.con!.backend.getAncestorList(spid: selectionSPID, stopAtPath: nil)
                let ancestorGUIDList: [GUID] = ancestorList.map({ $0.spid.guid })

                DispatchQueue.main.async {
                    self.con!.treeView!.expand(ancestorGUIDList, isAlreadyPopulated: false)
                    self.selectSPID(selectionSPID)
                    // Fall through and show window.
                }
            } catch {
                self.con!.reportException("Failed to restore tree selection", error)
                // Fall through and still show window:
            }
        }

        DispatchQueue.main.async {
            NSLog("INFO  [\(self.winID)] onPopulateTreeDone(): showing window")
            self.showWindow()
        }
    }

    func onSelectionChanged(_ senderID: SenderID, _ props: PropDict) throws {
        // default to nothing
    }

}
