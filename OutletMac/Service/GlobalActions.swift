//
// Created by Matthew Svoboda on 22/2/18.
// Copyright (c) 2022 Matt Svoboda. All rights reserved.
//

import AppKit

/*
 App-wide actions
 */
class GlobalActions {
    private typealias ActionHandler = (GlobalAction) -> Void

    private var actionHandlerDict: [ActionID : Selector] = [:]

    init() {
        actionHandlerDict = [
            .DIFF_TREES_BY_CONTENT: #selector(OutletMacApp.diffTreesByContent),
            .MERGE_CHANGES: #selector(OutletMacApp.mergeDiffChanges),
            .CANCEL_DIFF: #selector(OutletMacApp.cancelDiff)
        ]
    }

    func forActionID(_ actionID: ActionID) -> Selector? {
        return actionHandlerDict[actionID]
    }

}
