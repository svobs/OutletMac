//
//  Constants.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-17.
//

import SwiftUI

typealias MD5 = String
typealias SHA256 = String

// Logging
let SUPER_DEBUG_ENABLED: Bool = true  // TODO: externalize this
let TRACE_ENABLED: Bool = false // TODO: externalize this

let GRPC_CHANGE_TREE_NO_OP: UInt32 = 9

// Config keys

let DRAG_MODE_CONFIG_PATH: String = "ui_state.\(ID_MAIN_WINDOW).drag_mode"
let DIR_CONFLICT_POLICY_CONFIG_PATH: String = "ui_state.\(ID_MAIN_WINDOW).dir_conflict_policy"
let FILE_CONFLICT_POLICY_CONFIG_PATH: String = "ui_state.\(ID_MAIN_WINDOW).file_conflict_policy"

// --- FRONT END ONLY ---

let APP_NAME = "Outlet"

// Whether to use the system images, or to use the ones from the backend
let USE_SYSTEM_TOOLBAR_ICONS: Bool = true

let DEFAULT_ICON_SIZE: Int = 24
let TREE_VIEW_CELL_HEIGHT: CGFloat = 32.0

// For NSOutlineView
let NAME_COL_KEY = "name"
let SIZE_COL_KEY = "size"
let ETC_COL_KEY = "etc"
let MODIFY_TS_COL_KEY = "mtime"
let META_CHANGE_TS_COL_KEY = "ctime"


enum ColSortOrder: Int {
  case NAME = 1
  case SIZE = 2
  case MODIFY_TS = 3
  case CHANGE_TS = 4
}

// Padding in pixels
let H_PAD: CGFloat = 5
let V_PAD: CGFloat = 5

let DEFAULT_MAIN_WIN_X: CGFloat = 50
let DEFAULT_MAIN_WIN_Y: CGFloat = 50
let DEFAULT_MAIN_WIN_WIDTH: CGFloat = 1200
let DEFAULT_MAIN_WIN_HEIGHT: CGFloat = 500

let MAX_NUMBER_DISPLAYABLE_CHILD_NODES: UInt32 = 10000

let FILTER_APPLY_DELAY_MS = 200
let WIN_SIZE_STORE_DELAY_MS = 1000

let TIMER_TOLERANCE_SEC = 0.05

let DEFAULT_TERNARY_BTN_WIDTH: CGFloat = 32
let DEFAULT_TERNARY_BTN_HEIGHT: CGFloat = 32

let BUTTON_SHADOW_RADIUS: CGFloat = 1.0

let TEXT_BOX_FONT = Font.system(size: 20.0)
let DEFAULT_FONT = TEXT_BOX_FONT
let ROOT_PATH_ENTRY_FONT = TEXT_BOX_FONT
let FILTER_ENTRY_FONT = TEXT_BOX_FONT
let TREE_VIEW_NSFONT: NSFont = NSFont.systemFont(ofSize: 12.0)
//let TREE_VIEW_NSFONT: NSFont = NSFont.init(name: "Monaco", size: 18.0)!
//let TREE_ITEM_ICON_HEIGHT: Int = 20

enum WindowMode: Int {
  case BROWSING = 1
  case DIFF = 2
}

/**
 For drag & drop
 */
enum DragOperation: UInt32 {
  case MOVE = 1
  case COPY = 2
  case LINK = 3
  case DELETE = 4

  func getNSDragOperation() -> NSDragOperation {
    switch self {
    case .MOVE:
      return NSDragOperation.move
    case .COPY:
      return NSDragOperation.copy
    case .LINK:
      return NSDragOperation.link
    case .DELETE:
      return NSDragOperation.delete
    }
  }
}

/**
  For operations where the src dir and dst dir have same name but different content.
  This determines the operations which are created at the time of drop.
 */
enum DirConflictPolicy: UInt32 {
  case PROMPT = 1
  case SKIP = 2
  case REPLACE = 10
  case RENAME = 20
  case MERGE = 30
}

/**
  For operations where the src file and dst file has same same name but different content.
  This determines the operations which are created at the time of drop.
 */
enum FileConflictPolicy: UInt32 {
  case PROMPT = 1
  case SKIP = 2
  case REPLACE_ALWAYS = 10
  case REPLACE_IF_OLDER_AND_DIFFERENT = 11
  case RENAME_ALWAYS = 20
  case RENAME_IF_OLDER_AND_DIFFERENT = 21
  case RENAME_IF_DIFFERENT = 22
}

/**
 For batch failures
 */
enum ErrorHandlingStrategy: UInt32 {
  case PROMPT = 1
  case PAUSE_EXECUTION = 2  // TODO: maybe delete
  case CANCEL_BATCH = 3
  case CANCEL_FAILED_OPS_AND_DEPENDENTS = 4
}

/**
 ENUM IconNames
 
 Used for locating files in the filesystem.
 */
enum IconNames: String {
  // File icon names:
  case ICON_GENERIC_FILE = "backend/store/local"
  case ICON_FILE_RM = "file-rm"
  case ICON_FILE_MV_SRC = "file-mv-src"
  case ICON_FILE_UP_SRC = "file-up-src"
  case ICON_FILE_CP_SRC = "file-cp-src"
  case ICON_FILE_MV_DST = "file-mv-dst"
  case ICON_FILE_UP_DST = "file-up-dst"
  case ICON_FILE_CP_DST = "file-cp-dst"
  case ICON_FILE_TRASHED = "file-trashed"

  // Dir icon names:
  case ICON_GENERIC_DIR = "dir"
  case ICON_DIR_MK = "dir-mk"
  case ICON_DIR_RM = "dir-rm"
  case ICON_DIR_MV_SRC = "dir-mv-src"
  case ICON_DIR_UP_SRC = "dir-up-src"
  case ICON_DIR_CP_SRC = "dir-cp-src"
  case ICON_DIR_MV_DST = "dir-mv-dst"
  case ICON_DIR_UP_DST = "dir-up-dst"
  case ICON_DIR_CP_DST = "dir-cp-dst"
  case ICON_DIR_TRASHED = "dir-trashed"
  case ICON_DIR_PENDING_DOWNSTREAM_OP = "dir-pending-downstream-op"

  // Various icon names:
  case ICON_ALERT = "alert"
  case ICON_WINDOW = "win"
  case ICON_REFRESH = "refresh"
  case ICON_FOLDER_TREE = "folder-tree"
  case ICON_MATCH_CASE = "match-case"
  case ICON_IS_SHARED = "is-shared"
  case ICON_IS_NOT_SHARED = "is-not-shared"
  case ICON_IS_TRASHED = "is-trashed"
  case ICON_IS_NOT_TRASHED = "is-not-trashed"
  case ICON_PLAY = "play"
  case ICON_PAUSE = "pause"

  // Root icon names:
  case ICON_GDRIVE = "gdrive"
  case ICON_LOCAL_DISK_LINUX = "localdisk-linux"

  case BTN_GDRIVE = "gdrive-btn"
  case BTN_LOCAL_DISK_LINUX = "localdisk-linux-btn"

  case ICON_LOADING = "loading"
}

// --- FE + BE SHARED ---

/**
 ENUM IconID
 
 Used for identifying icons in a compact way. Each IconID has an associated image which can be retrieved from the backend,
 but may alternatively be represented by a MacOS system image.
 */
enum IconID: UInt32 {
  case NONE = 0

  case ICON_GENERIC_FILE = 1
  case ICON_FILE_RM = 2
  case ICON_FILE_MV_SRC = 3
  case ICON_FILE_UP_SRC = 4
  case ICON_FILE_CP_SRC = 5
  case ICON_FILE_MV_DST = 6
  case ICON_FILE_UP_DST = 7
  case ICON_FILE_CP_DST = 8
  case ICON_FILE_TRASHED = 9

  case ICON_GENERIC_DIR = 10
  case ICON_DIR_MK = 11
  case ICON_DIR_RM = 12
  case ICON_DIR_MV_SRC = 13
  case ICON_DIR_UP_SRC = 14
  case ICON_DIR_CP_SRC = 15
  case ICON_DIR_MV_DST = 16
  case ICON_DIR_UP_DST = 17
  case ICON_DIR_CP_DST = 18
  case ICON_DIR_TRASHED = 19
  case ICON_DIR_PENDING_DOWNSTREAM_OP = 130

  // toolbar icons:
  case ICON_ALERT = 20
  case ICON_WINDOW = 21
  case ICON_REFRESH = 22
  case ICON_PLAY = 23
  case ICON_PAUSE = 24
  case ICON_FOLDER_TREE = 25
  case ICON_MATCH_CASE = 26
  case ICON_IS_SHARED = 27
  case ICON_IS_NOT_SHARED = 28
  case ICON_IS_TRASHED = 29
  case ICON_IS_NOT_TRASHED = 30

  case ICON_LOCAL_DISK_LINUX = 31
  case ICON_LOCAL_DISK_MACOS = 32
  case ICON_LOCAL_DISK_WINDOWS = 33
  case ICON_GDRIVE = 34

  // toolbar icons:
  case BTN_FOLDER_TREE = 40
  case BTN_LOCAL_DISK_LINUX = 41
  case BTN_LOCAL_DISK_MACOS = 42
  case BTN_LOCAL_DISK_WINDOWS = 43
  case BTN_GDRIVE = 44

  case ICON_LOADING = 50

  case ICON_TO_ADD = 51
  case ICON_TO_DELETE = 52
  case ICON_TO_UPDATE = 53
  case ICON_TO_MOVE = 54

  case BADGE_RM = 100
  case BADGE_MV_SRC = 101
  case BADGE_MV_DST = 102
  case BADGE_CP_SRC = 103
  case BADGE_CP_DST = 104
  case BADGE_UP_SRC = 105
  case BADGE_UP_DST = 106
  case BADGE_MKDIR = 107

  case BADGE_TRASHED = 108
  case BADGE_CANCEL = 109
  case BADGE_REFRESH = 110

  case BADGE_LINUX = 120
  case BADGE_MACOS = 121
  case BADGE_WINDOWS = 122

  func isAnimated() -> Bool {
    switch self {
    case .ICON_LOADING:
      return true
    default:
      return false
    }
  }

  func isToolbarIcon() -> Bool {
    if (self.rawValue >= IconID.ICON_ALERT.rawValue && self.rawValue <= IconID.ICON_IS_NOT_TRASHED.rawValue) ||
               (self.rawValue >= IconID.BTN_FOLDER_TREE.rawValue && self.rawValue <= IconID.BTN_GDRIVE.rawValue) {
      return true
    }
    return false
  }

  func isNodeIcon() -> Bool {
    return !self.isToolbarIcon()
  }

  /**
   Each icon can have an associated MacOS system image.
   Reminder: we can use the "SF Symbols" app to browse system images and their names
   */
  func systemImageName() -> String {
    // Some of these are really bad... unfortunately, Apple doesn't give us a lot to work with
    switch self {
      case .ICON_ALERT:
        return "exclamationmark.triangle.fill"
      case .ICON_WINDOW:
        return "macwindow.on.rectangle"
      case .ICON_REFRESH:
        return "arrow.clockwise"
      case .ICON_PLAY:
        return "play.fill"
      case .ICON_PAUSE:
        return "pause.fill"
      case .ICON_FOLDER_TREE:
        return "network"
      case .ICON_MATCH_CASE:
        return "textformat"
      case .ICON_IS_SHARED:
        return "person.2.fill"
      case .ICON_IS_NOT_SHARED:
        return "person.fill"
      case .ICON_IS_TRASHED:
        return "trash"
      case .ICON_IS_NOT_TRASHED:
        return "trash.slash"
      case .ICON_GDRIVE:
        return "externaldrive"
      case .ICON_LOCAL_DISK_LINUX:
        return "externaldrive"
      case .BTN_GDRIVE:
        return "externaldrive"
      case .BTN_LOCAL_DISK_LINUX:
        return "externaldrive"
      default:
        preconditionFailure("No system image has been defined for: \(self)")
    }
  }

}

let ICON_DEFAULT_ERROR_SYSTEM_IMAGE_NAME = "multiply.circle.fill"


let ROOT_PATH = "/"

// See: https://github.com/grpc/grpc/blob/master/doc/keepalive.md
let GRPC_CONNECTION_TIMEOUT_SEC: Int64 = 20
let GRPC_MAX_CONNECTION_RETRIES: Int = 3

let DEFAULT_GRPC_SERVER_ADDRESS = "localhost"
let DEFAULT_GRPC_SERVER_PORT = 50051

let LOOPBACK_ADDRESS = "127.0.0.1"

let BONJOUR_SERVICE_DISCOVERY_TIMEOUT_SEC = 10.0
let BONJOUR_RESOLUTION_TIMEOUT_SEC = 5.0

let BONJOUR_SERVICE_TYPE = "_outlet._tcp."
let BONJOUR_SERVICE_DOMAIN = "local."

let SIGNAL_THREAD_SLEEP_PERIOD_SEC: Double = 3

typealias UID = UInt32
typealias GUID = String
typealias TreeID = String

/**
 ENUM TrashStatus
 
 Indicates whether a node is in the trash. Note: IMPLICITLY_TRASHED only applies to GDrive nodes.
 */
enum TrashStatus: UInt32 {
  case NOT_TRASHED = 0
  case EXPLICITLY_TRASHED = 1
  case IMPLICITLY_TRASHED = 2
  case DELETED = 3

  func notTrashed() -> Bool {
    return self == TrashStatus.NOT_TRASHED
  }
  
  func toString() -> String {
    return TrashStatus.display(self.rawValue)
  }
  
  static func display(_ code: UInt32) -> String {
    guard let status = TrashStatus(rawValue: code) else {
      return "UNKNOWN"
    }

    switch status {
      case .NOT_TRASHED:
        return "No"
      case .EXPLICITLY_TRASHED:
        return "UserTrashed"
      case .IMPLICITLY_TRASHED:
        return "Trashed"
      case .DELETED:
        return "Deleted"
    }
  }
}

/**
 ENUM TreeType
 
 The type of node, or DisplayTree. DisplayTree of type MIXED can contain nodes of different TreeType, but all other DisplayTree tree types must
 be homogenous with respect to their nodes' tree types.
 */
enum TreeType: UID {
  case NA = 0
  case MIXED = 1
  case LOCAL_DISK = 2
  case GDRIVE = 3
  
  func getName() -> String {
    switch self {
      case .NA:
        return "None"
      case .MIXED:
        return "Super Root"
      case .LOCAL_DISK:
        return "Local Disk"
      case .GDRIVE:
        return "Google Drive"
    }
  }
  
  static func display(_ treeType: TreeType) -> String {
    switch treeType {
      case .NA:
        return "✪"
      case .MIXED:
        return "M"
      case .LOCAL_DISK:
        return "L"
      case .GDRIVE:
        return "G"
    }
  }
}

// UID reserved values:
let NULL_UID: UID = TreeType.NA.rawValue
let SUPER_ROOT_UID = TreeType.MIXED.rawValue
let LOCAL_ROOT_UID = TreeType.LOCAL_DISK.rawValue
let GDRIVE_ROOT_UID = TreeType.GDRIVE.rawValue
let ROOT_PATH_UID = LOCAL_ROOT_UID

let SUPER_ROOT_DEVICE_UID = SUPER_ROOT_UID

let MIN_FREE_UID: UID = 100

let LOADING_MESSAGE: String = "Loading..."

let GDRIVE_FOLDER_MIME_TYPE_UID: UID = 1

let GDRIVE_ME_USER_UID: UID = 1

enum TreeLoadState: UInt32 {
  case UNKNOWN = 0  // should never be sent
  case NOT_LOADED = 1  // also not sent
  case LOAD_STARTED = 2  // it's ready for clients to start querying for nodes
  case COMPLETELY_LOADED = 10  // final state
}

/**
 ENUM TreeDisplayMode
 
 Indicates the current behavior of a displayed tree in the UI. ONE_TREE_ALL_ITEMS is the default. CHANGES_ONE_TREE_PER_CATEGORY is for diffs.
 */
enum TreeDisplayMode: UInt32 {
  case ONE_TREE_ALL_ITEMS = 1
  case CHANGES_ONE_TREE_PER_CATEGORY = 2
}

let CFG_KEY_TREE_ICON_SIZE = "display.image.tree_icon_size"
let CFG_KEY_TOOLBAR_ICON_SIZE = "display.image.toolbar_icon_size"
let CFG_KEY_USE_NATIVE_TOOLBAR_ICONS = "display.image.use_native_toolbar_icons"
let CFG_KEY_USE_NATIVE_TREE_ICONS = "display.image.use_native_tree_icons"
