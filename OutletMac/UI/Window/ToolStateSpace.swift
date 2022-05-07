//
// Created by Matthew Svoboda on 22/2/9.
// Copyright (c) 2022 Matt Svoboda. All rights reserved.
//
import Cocoa
import OutletCommon

extension NSImage.Name {
    static let modeCopy = NSImage.Name("ModeCopy")
    static let modeMove = NSImage.Name("ModeMove")

    static let promptUser = NSImage.Name("PromptUser")

    static let skipFolder = NSImage.Name("Folder-Skip")
    static let replaceFolder = NSImage.Name("Folder-Replace")
    static let keepBothFolders = NSImage.Name("Folder-KeepBoth")
    static let mergeFolders = NSImage.Name("Folder-Merge")

    static let skipFile = NSImage.Name("File-Skip")
    static let replaceFileAlways = NSImage.Name("File-ReplaceAlways")
    static let replaceOldFileWithNewOnly = NSImage.Name("File-ReplaceOldWithNewOnly")
    static let keepBothFiles = NSImage.Name("File-KeepBoth")
    static let keepBothFilesIfDifferent = NSImage.Name("File-KeepBothIfDifferent")
}

enum PickerItemIdentifier: Equatable {
    case DragMode(DragOperation)
    case DirPolicy(DirConflictPolicy)
    case FilePolicy(FileConflictPolicy)
}

class PickerItem {
    init(_ identifier: PickerItemIdentifier, _ title: String, _ image: NSImage, _ setterActionID: ActionID, toolTip: String) {
        self.identifier = identifier
        self.title = title
        self.image = image
        self.setterActionID = setterActionID
        self.toolTip = toolTip
    }

    let identifier: PickerItemIdentifier
    let title: String
    let image: NSImage
    let toolTip: String
    let setterActionID: ActionID

    func toMenuItemMeta() -> MenuItemMeta {
        return MenuItemMeta(itemType: .NORMAL, title: self.title, actionType: .BUILTIN(self.setterActionID))
    }
}

/**
 A PickerGroup consists of a set of PickerItems.
 */
class PickerGroup: Hashable {
    static func ==(lhs: PickerGroup, rhs: PickerGroup) -> Bool {
        // We are really just implementing Hashable to make the compiler happy, but this field should be enough to be unique for our purposes
        return lhs.groupLabel == rhs.groupLabel
    }

    func hash(into hasher: inout Hasher) {
        // ditto as above
        hasher.combine(groupLabel)
    }

    init(_ itemList: [PickerItem], groupLabel: String, tooltipTemplate: String) {
        self.itemList = itemList
        self.groupLabel = groupLabel
        self.tooltipTemplate = tooltipTemplate
    }

    let itemList: [PickerItem]
    let groupLabel: String
    let tooltipTemplate: String

    func toMenuMeta() -> MenuItemMeta {
        let menu = SubmenuItemMeta(title: groupLabel)

        for item in itemList {
            menu.submenuItemList.append(item.toMenuItemMeta())
        }

        return menu
    }
}


/**
 Represents all the possible tool states for the application.
 */
class ToolStateSpace {

    static let dragModeGroup = PickerGroup(
        [
            PickerItem(.DragMode(.COPY), "Copy", NSImage(named: .modeCopy)!, .SET_DEFAULT_DRAG_MODE_TO_COPY,
                    toolTip: "Copy dragged item[s] to destination"),
            PickerItem(.DragMode(.MOVE), "Move", NSImage(named: .modeMove)!, .SET_DEFAULT_DRAG_MODE_TO_MOVE,
                    toolTip: "Move dragged item[s] to destination")
        ],
        groupLabel: "Drag Mode",
        tooltipTemplate: "Set the default mode for Drag & Drop (Copy or Move)")

    static let dirConflictPolicyGroup = PickerGroup(
        [
            PickerItem(.DirPolicy(.PROMPT), "Prompt user", NSImage(named: .promptUser)!, .SET_DEFAULT_DIR_CONFLICT_POLICY_TO_PROMPT,
                    toolTip: "Ask user what to do every time"),
            PickerItem(.DirPolicy(.SKIP), "Skip folder", NSImage(named: .skipFolder)!, .SET_DEFAULT_DIR_CONFLICT_POLICY_TO_SKIP,
                    toolTip: "Skip operation for folder (leave folder at destination untouched)"),
            PickerItem(.DirPolicy(.REPLACE), "Replace folder", NSImage(named: .replaceFolder)!, .SET_DEFAULT_DIR_CONFLICT_POLICY_TO_REPLACE,
                    toolTip: "Completely replace the destination folder"),
            PickerItem(.DirPolicy(.RENAME), "Keep both folders", NSImage(named: .keepBothFolders)!, .SET_DEFAULT_DIR_CONFLICT_POLICY_TO_RENAME,
                    toolTip: "Leave destination folder, but put source folder alongside it with a new name"),
            PickerItem(.DirPolicy(.MERGE), "Merge", NSImage(named: .mergeFolders)!, .SET_DEFAULT_DIR_CONFLICT_POLICY_TO_MERGE,
                    toolTip: "Merge source folder's tree into destination folder, merging any sub-folders which conflict, and following File Conflict Policy for any files which conflict")
        ],
        groupLabel: "Folder Conflict Policy",
        tooltipTemplate: "When moving or copying: what to do when the destination already contains a folder with the same name as a folder being copied")

    static let fileConflictPolicyGroup = PickerGroup(
        [
            PickerItem(.FilePolicy(.PROMPT), "Prompt user", NSImage(named: .promptUser)!, .SET_DEFAULT_FILE_CONFLICT_POLICY_TO_PROMPT,
                    toolTip: "Ask user what to do every time"),
            PickerItem(.FilePolicy(.SKIP), "Skip file", NSImage(named: .skipFile)!, .SET_DEFAULT_FILE_CONFLICT_POLICY_TO_SKIP,
                    toolTip: "Skip operation for file (leave file at destination untouched)"),
            PickerItem(.FilePolicy(.REPLACE_ALWAYS), "Overwrite always", NSImage(named: .replaceFileAlways)!,
                    .SET_DEFAULT_FILE_CONFLICT_POLICY_TO_REPLACE_ALWAYS,
                    toolTip: "Replace the destination file with the source file"),
            PickerItem(.FilePolicy(.REPLACE_IF_OLDER_AND_DIFFERENT), "Overwrite old with new only", NSImage(named: .replaceOldFileWithNewOnly)!,
                    .SET_DEFAULT_FILE_CONFLICT_POLICY_TO_REPLACE_IF_OLDER_AND_DIFFERENT,
                    toolTip: "Replace the destination file only if the source file is newer"),
            // TODO: may want to disable this one, for simplicity:
            PickerItem(.FilePolicy(.RENAME_ALWAYS), "Keep both always", NSImage(named: .keepBothFiles)!,
                    .SET_DEFAULT_FILE_CONFLICT_POLICY_TO_RENAME_ALWAYS,
                    toolTip: "Don't touch destination file, but add source file alongside it with a new name. If the files have the same content this will result in duplicate files side by side."),
            PickerItem(.FilePolicy(.RENAME_IF_DIFFERENT), "Keep both only if different", NSImage(named: .modeMove)!,
                    .SET_DEFAULT_FILE_CONFLICT_POLICY_TO_RENAME_IF_DIFFERENT,
                    toolTip: "Don't touch destination file, but if source and destination files are different, the source file will be added alongside the destination with a new name")
        ],
        groupLabel: "File Conflict Policy",
        tooltipTemplate: "When moving or copying: what to do when the destination already contains a file with the same name as a file being copied")

    static let groupList = [dragModeGroup, dirConflictPolicyGroup, fileConflictPolicyGroup]

    static let setterActionMap: [ActionID : PickerItem] = buildSetterActionMap()

    private static func buildSetterActionMap() -> [ActionID : PickerItem] {
        var map: [ActionID : PickerItem] = [:]
        for group in groupList {
            for pickerItem in group.itemList {
                map[pickerItem.setterActionID] = pickerItem
            }
        }
        return map
    }
}
