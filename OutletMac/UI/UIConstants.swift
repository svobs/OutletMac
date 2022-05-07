//
//  Constants.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-17.
//

import SwiftUI
import OutletCommon

typealias MD5 = String
typealias SHA256 = String

// Config keys

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
let CREATE_TS_COL_KEY = "crtime"
let MODIFY_TS_COL_KEY = "mtime"
let META_CHANGE_TS_COL_KEY = "ctime"


enum ColSortOrder: Int {
  case NAME = 1
  case SIZE = 2
  case CREATE_TS = 3
  case MODIFY_TS = 4
  case CHANGE_TS = 5
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
