//
// Created by Matthew Svoboda on 21/9/7.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

/**
 The EnvironmentObject containing shared state for all UI components in the app
 */
class GlobalState: ObservableObject {
    @Published var isBackendOpExecutorRunning = false

    @Published var deviceList: [Device] = []

    // Alert stuff:
    @Published var showingAlert = false
    @Published var alertTitle: String = "Alert" // placeholder msg
    @Published var alertMsg: String = "An unknown error occurred" // placeholder msg
    @Published var dismissButtonText: String = "Dismiss" // placeholder msg

    // These are really window-specific:

    /*
     If false, disable filter controls, drag & drop
     */
    @Published var isUIEnabled: Bool = true

    @Published var mode: WindowMode = .BROWSING

    // --------------------------------------------------------------------------------------------
    // Not published, but this is the most logical place to store these. These will be updated from the backend values at startup, and
    // the backend will be notified every time they're changed

    // This is the value set in the toolbar/menu, but can be overridden by modifierKeyDragOperation
    var currentDragOperation: DragOperation = .COPY {
        willSet {
            guard currentDragOperation != newValue else {
                return
            }

            NSLog("DEBUG [\(ID_APP)] Changing DefaultDragOperation from \(currentDragOperation) to \(newValue)")
        }
    }
    // FIXME: bug: this doesn't get changed during a drag; it's frozen when the drag starts
    var modifierKeyDragOperation: DragOperation? = nil

    var currentDirConflictPolicy: DirConflictPolicy = .MERGE {
        willSet {
            guard currentDirConflictPolicy != newValue else {
                return
            }

            NSLog("DEBUG [\(ID_APP)] Changing DirConflictPolicy from \(currentDirConflictPolicy) to \(newValue)")
        }
    }

    var currentFileConflictPolicy: FileConflictPolicy = .RENAME_IF_DIFFERENT {
        willSet {
            guard currentFileConflictPolicy != newValue else {
                return
            }

            NSLog("DEBUG [\(ID_APP)] Changing FileConflictPolicy from \(currentFileConflictPolicy) to \(newValue)")
        }
    }
    // --------------------------------------------------------------------------------------------

    func getCurrentDefaultDragOperation() -> DragOperation {
        if let modifierKeyDragOperation = self.modifierKeyDragOperation {
            return modifierKeyDragOperation
        } else {
            return currentDragOperation
        }
    }

    /**
     This method will cause an alert to be displayed in the MainContentView.
     */
    func showAlert(title: String, msg: String, dismissButtonText: String = "Dismiss") {
        NSLog("DEBUG Showing alert with title='\(title)', msg='\(msg)'")
        assert(DispatchQueue.isExecutingIn(.main))
        if self.showingAlert && self.alertTitle == title && self.alertMsg == msg && self.dismissButtonText == dismissButtonText {
            NSLog("DEBUG Already showing identical alert; ignoring")
        } else {
            self.alertTitle = title
            self.alertMsg = msg
            self.dismissButtonText = dismissButtonText
            self.showingAlert = true
        }
    }

    func reset() {
        NSLog("DEBUG Resetting globalState")
        assert(DispatchQueue.isExecutingIn(.main))
        mode = .BROWSING
        dismissAlert()
        isUIEnabled = true
    }

    func dismissAlert() {
        NSLog("DEBUG Dismissing alert")
        assert(DispatchQueue.isExecutingIn(.main))
        self.showingAlert = false
        self.alertMsg = ""
        self.alertTitle = "Alert"
    }
}
