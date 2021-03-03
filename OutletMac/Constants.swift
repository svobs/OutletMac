//
//  Constants.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-17.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

typealias MD5 = String
typealias SHA256 = String

// --- FRONT END ONLY ---

let APP_NAME = "Outlet"

// Padding in pixels
let H_PAD: CGFloat = 5
let V_PAD: CGFloat = 5

let MAX_NUMBER_DISPLAYABLE_CHILD_NODES: UInt32 = 10000

let FILTER_APPLY_DELAY_MS = 200
let STATS_REFRESH_HOLDOFF_TIME_MS = 1000

let TIMER_TOLERANCE_SEC = 0.05

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
}

/**
 ENUM IconId
 
 Used for identifying icons in a more compact way, mainly for serialization for RPC
 */
enum IconId: UInt32 {
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

  case ICON_GDRIVE = 31
  case ICON_LOCAL_DISK_LINUX = 32

  case BTN_GDRIVE = 33
  case BTN_LOCAL_DISK_LINUX = 34
}


// --- FE + BE SHARED ---

let ROOT_PATH = "/"

let LOOPBACK_ADDRESS = "127.0.0.1"

let ZEROCONF_SERVICE_NAME = "OutletService"
let ZEROCONF_SERVICE_VERSION = "1.0.0"
let ZEROCONF_SERVICE_TYPE = "_outlet._tcp.local."

typealias UID = UInt32

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
        return "Mixed"
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

let MIN_FREE_UID: UID = 100


let GDRIVE_FOLDER_MIME_TYPE_UID: UID = 1

let GDRIVE_ME_USER_UID: UID = 1


/**
 ENUM TreeDisplayMode
 
 Indicates the current behavior of a displayed tree in the UI. ONE_TREE_ALL_ITEMS is the default. CHANGES_ONE_TREE_PER_CATEGORY is for diffs.
 */
enum TreeDisplayMode: UInt32 {
  case ONE_TREE_ALL_ITEMS = 1
  case CHANGES_ONE_TREE_PER_CATEGORY = 2
}
