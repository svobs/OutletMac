//
// Created by Matthew Svoboda on 21/9/7.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

/**
 The EnvironmentObject containing shared state for all UI components in the app
 */
class GlobalState: ObservableObject {
    @Published var isPlaying = false

    @Published var deviceList: [Device] = []

    @Published var mode: WindowMode = .BROWSING

    // Alert stuff:
    @Published var showingAlert = false
    @Published var alertTitle: String = "Alert" // placeholder msg
    @Published var alertMsg: String = "An unknown error occurred" // placeholder msg
    @Published var dismissButtonText: String = "Dismiss" // placeholder msg

    @Published var isUIEnabled: Bool = true

    // Not published, but this is the most logical place to store it:
    var currentDefaultDragOperation: DragOperation = INITIAL_DEFAULT_DRAG_OP

    /**
     This method will cause an alert to be displayed in the MainContentView.
     */
    func showAlert(title: String, msg: String, dismissButtonText: String = "Dismiss") {
        NSLog("DEBUG Showing alert with title='\(title)', msg='\(msg)'")
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
        isUIEnabled = true
        mode = .BROWSING
        dismissAlert()
    }

    func dismissAlert() {
        NSLog("DEBUG Dismissing alert")
        self.showingAlert = false
        self.alertMsg = ""
        self.alertTitle = "Alert"
    }
}
