//
// Created by Matthew Svoboda on 22/2/18.
// Copyright (c) 2022 Matt Svoboda. All rights reserved.
//

import AppKit
import OutletCommon

/**
 App-wide actions
 Note: It's currently unclear to me whether this needs to implement NSResponder in order to accept actions - but it works!
 */
class GlobalActions: NSResponder, NSUserInterfaceValidations {
    private typealias ActionHandler = (GlobalAction) -> Void
    weak var app: OutletMacApp! = nil

    private var actionHandlerDict: [ActionID : Selector] = [:]

    override init() {
        actionHandlerDict = [
            .DIFF_TREES_BY_CONTENT: #selector(GlobalActions.diffTreesByContent),
            .MERGE_CHANGES: #selector(GlobalActions.mergeDiffChanges),
            .CANCEL_DIFF: #selector(GlobalActions.cancelDiff)
        ]
        super.init()
    }

    required init(coder: NSCoder) {
        super.init()
    }


    func forActionID(_ actionID: ActionID) -> Selector? {
        return actionHandlerDict[actionID]
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if SUPER_DEBUG_ENABLED {
            NSLog("DEBUG [GlobalActions] validateUserInterfaceItem(): \(item)")
        }
        return true
    }

    /**
    VALIDATE MENU ITEM
    Called by certain menu items, when they are drawn, to determine if they should be enabled.
    - Returns: true if the given menu item should be enabled, false if it should be disabled
    */
    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if SUPER_DEBUG_ENABLED {
            NSLog("DEBUG [GlobalActions] Entered validateMenuItem() for item \(item)'")
        }

        if let generatedItem = item as? GeneratedMenuItem {
            let actionType = generatedItem.menuItemMeta.actionType

            updateCheckboxStateIfIsPickerItem(actionType, item)

            return isActionValid(actionType)
        }

        return true
    }

    private func updateCheckboxStateIfIsPickerItem(_ actionType: ActionType, _ menuItem: NSMenuItem) {
        switch actionType {
        case .BUILTIN(let actionID):
            // Check for toolbar states first (there are many):
            if let pickerItem = ToolStateSpace.setterActionMap[actionID] {
                switch pickerItem.identifier {
                case .DragMode(let dragOperation):
                    menuItem.state = (self.app.globalState.currentDragOperation == dragOperation) ? .on : .off
                case .DirPolicy(let policy):
                    menuItem.state = (self.app.globalState.currentDirConflictPolicy == policy) ? .on : .off
                case .FilePolicy(let policy):
                    menuItem.state = (self.app.globalState.currentFileConflictPolicy == policy) ? .on : .off
                }
            }
        default:
            break
        }
    }

    func isActionValid(_ actionType: ActionType) -> Bool {
        switch actionType {
        case .BUILTIN(let actionID):
            // Check for toolbar states first (there are many):
            if let pickerItem = ToolStateSpace.setterActionMap[actionID] {
                NSLog("DEBUG [\(ID_APP)] isActionValid(): Returning true for pickerItem: \(pickerItem.identifier)'")
                return true
            }

            switch actionID {
            case .DIFF_TREES_BY_CONTENT:
                if let mainWin = self.app.mainWindow, mainWin.isVisible && self.app.globalState.isUIEnabled && self.app.globalState.mode == .BROWSING {
                    return true
                } else {
                    return false
                }
            case .MERGE_CHANGES:
                if let mainWin = self.app.mainWindow, mainWin.isVisible && self.app.globalState.isUIEnabled && self.app.globalState.mode == .DIFF {
                    return true
                } else {
                    return false
                }
            case .CANCEL_DIFF:
                if let mainWin = self.app.mainWindow, mainWin.isVisible && self.app.globalState.isUIEnabled && self.app.globalState.mode == .DIFF {
                    return true
                } else {
                    return false
                }
            default:
                NSLog("ERROR [\(ID_APP)] isActionValid(): returning isEnabled=false for unrecognzied menu item type=BUILTIN actionID=\(actionID)")
                return false
            }
        default:
            NSLog("ERROR [\(ID_APP)] isActionValid(): returning isEnabled=false for unrecognzied menu item actionType=\(actionType)")
            return false
        }
    }

    /**
    EXECUTE GLOBAL ACTION
    This includes menu item actions.
    */
    @objc public func executeGlobalMenuAction(_ sender: GeneratedMenuItem) {
        let actionType = sender.menuItemMeta.actionType
        NSLog("DEBUG Entered executeGlobalMenuAction(): actionType='\(actionType)'")

        switch actionType {
        case .BUILTIN (let actionID):
            // Try global actions first
            if let selector = self.forActionID(actionID) {
                NSLog("DEBUG executeGlobalMenuAction(): Executing global action: \(actionType)'")
                NSApp.sendAction(selector, to: self, from: self)
                return
            }

            // Now try picker item
            if let pickerItem = ToolStateSpace.setterActionMap[actionID] {
                NSLog("DEBUG executeGlobalMenuAction(): Selecting PickerItem: \(pickerItem.identifier)")
                self.changePickerItem(pickerItem.identifier)
                return
            }
        default:
            NSLog("ERROR executeGlobalMenuAction(): Unrecognized actionType: \(actionType)'")
            return
        }
    }

    func changePickerItem(_ newSelection: PickerItemIdentifier) {
        switch newSelection {
        case PickerItemIdentifier.DragMode(let selectedMode):
            NSLog("INFO  [\(ID_APP)] User changed default drag operation: \(selectedMode)")
            self.changeDragMode(selectedMode)

        case PickerItemIdentifier.DirPolicy(let selectedPolicy):
            NSLog("INFO  [\(ID_APP)] User changed dir conflict policy: \(selectedPolicy)")
            self.changeDirConflictPolicy(selectedPolicy)

        case PickerItemIdentifier.FilePolicy(let selectedPolicy):
            NSLog("INFO  [\(ID_APP)] User changed file conflict policy: \(selectedPolicy)")
            self.changeFileConflictPolicy(selectedPolicy)
        }
    }

    private func changeDragMode(_ newMode: DragOperation) {
        // 1. Update in-memory state
        self.app.globalState.currentDragOperation = newMode

        // 2. Update persistent state
        do {
            try self.app.backend.putConfig(DRAG_MODE_CONFIG_PATH, String(newMode.rawValue))
        } catch {
            self.app.reportException("Failed to save Drag Mode selection", error)
        }

        // 3. Update toolbar UI
        app.mainWindow?.getMainToolbar()?.setToolbarSelection(.DragMode(newMode))
    }

    private func changeDirConflictPolicy(_ newPolicy: DirConflictPolicy) {
        self.app.globalState.currentDirConflictPolicy = newPolicy

        do {
            try self.app.backend.putConfig(DIR_CONFLICT_POLICY_CONFIG_PATH, String(newPolicy.rawValue))
        } catch {
            self.app.reportException("Failed to save Dir Conflict Policy selection", error)
        }

        app.mainWindow?.getMainToolbar()?.setToolbarSelection(.DirPolicy(newPolicy))
    }

    private func changeFileConflictPolicy(_ newPolicy: FileConflictPolicy) {
        self.app.globalState.currentFileConflictPolicy = newPolicy

        do {
            try self.app.backend.putConfig(FILE_CONFLICT_POLICY_CONFIG_PATH, String(newPolicy.rawValue))
        } catch {
            self.app.reportException("Failed to save File Conflict Policy selection", error)
        }

        app.mainWindow?.getMainToolbar()?.setToolbarSelection(.FilePolicy(newPolicy))
    }

    // Diff Trees
    // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

    /**
    Diff Trees By Content
    */
    @objc func diffTreesByContent() {
        if SUPER_DEBUG_ENABLED {
            NSLog("DEBUG [\(ID_APP)] Entered diffTreesByContent()")
        }

        guard isActionValid(.BUILTIN(.DIFF_TREES_BY_CONTENT)) else {
            // add specific error msg if appropriate
            if self.app.globalState.mode == .DIFF {
                self.app.reportError("Cannot start diff", "A diff is already in process, apparently (this is probably a bug)")
            }
            return
        }

        guard let conLeft = self.app.getTreePanelController(ID_LEFT_TREE) else {
            self.app.reportError("Cannot diff", "Internal error: no controller for \(ID_LEFT_TREE) found!")
            return
        }
        guard let conRight = self.app.getTreePanelController(ID_RIGHT_TREE) else {
            self.app.reportError("Cannot diff", "Internal error: no controller for \(ID_RIGHT_TREE) found!")
            return
        }

        // TODO: will this work if not loaded?
//    if conLeft.treeLoadState != .COMPLETELY_LOADED {
//      self.app.reportError("Cannot start diff", "Left tree is not finished loading")
//      return
//    }
//    if conRight.treeLoadState != .COMPLETELY_LOADED {
//      self.app.reportError("Cannot start diff", "Right tree is not finished loading")
//      return
//    }

        NSLog("DEBUG [\(ID_APP)] Sending request to BE to diff trees '\(conLeft.treeID)' & '\(conRight.treeID)'")

        // First disable UI
        self.app.sendEnableUISignal(enable: false)

        // Now ask BE to start the diff
        do {
            _ = try self.app.backend.startDiffTrees(treeIDLeft: conLeft.treeID, treeIDRight: conRight.treeID)
            //  We will be notified asynchronously when it is done/failed. If successful, the old tree_ids will be notified and supplied the new IDs
        } catch {
            NSLog("ERROR \(ID_APP)] Failed to start tree diff: \(error)")
            self.app.sendEnableUISignal(enable: true)
        }
    }

    /**
    Merge Changes
    */
    @objc func mergeDiffChanges() {

        guard isActionValid(.BUILTIN(.MERGE_CHANGES)) else {
            // add specific error msg if appropriate
            if self.app.globalState.mode != .DIFF {
                self.app.reportError("Cannot merge changes", "A diff is not currently in progress")
            }
            return
        }

        guard let conLeft = self.app.mainWindow?.conLeft else {
            self.app.reportError("Cannot merge", "Internal error: controller for left tree not found in main window!")
            return
        }
        guard let conRight = self.app.mainWindow?.conRight else {
            self.app.reportError("Cannot merge", "Internal error: controller for right tree not found in main window!")
            return
        }
        do {
            let selectedChangeListLeft = try conLeft.generateCheckedRowList()
            let selectedChangeListRight = try conRight.generateCheckedRowList()

            let guidListLeft: [GUID] = selectedChangeListLeft.map({ $0.spid.guid })
            let guidListRight: [GUID] = selectedChangeListRight.map({ $0.spid.guid })
            if SUPER_DEBUG_ENABLED {
                NSLog("INFO  Selected changes (Left) = \(selectedChangeListLeft.count): [\(selectedChangeListLeft.map({ "\($0.spid)" }).joined(separator: "  "))]")
                NSLog("INFO  Selected changes (Right) = \(selectedChangeListRight.count): [\(selectedChangeListRight.map({ "\($0.spid)" }).joined(separator: "  "))]")
            }

            self.app.sendEnableUISignal(enable: false)

            try self.app.backend.generateMergeTree(treeIDLeft: conLeft.treeID, treeIDRight: conRight.treeID,
                    selectedChangeListLeft: guidListLeft, selectedChangeListRight: guidListRight)

        } catch {
            self.app.reportException("Failed to generate merge preview", error)
            self.app.sendEnableUISignal(enable: true)
        }
    }

    /**
    Cancel Diff
    */
    @objc func cancelDiff() {
        guard isActionValid(.BUILTIN(.CANCEL_DIFF)) else {
            // add specific error msg if appropriate
            if self.app.globalState.mode != .DIFF {
                self.app.reportError("Cannot cancel diff", "A diff is not currently in progress")
            }
            return
        }
        NSLog("DEBUG CancelDiff activated! Sending signal: '\(Signal.EXIT_DIFF_MODE)'")
        self.app.dispatcher.sendSignal(signal: .EXIT_DIFF_MODE, senderID: ID_APP)
    }

}
