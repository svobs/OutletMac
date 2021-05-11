//
//  SignalConstants.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-11.
//

enum Signal: UInt32 {
  // Tasks
  case ENQUEUE_UI_TASK = 1
  case START_CACHEMAN = 2
  case START_OP_EXEC_THREAD = 3
  case LOAD_REGISTRY_DONE = 4
  case START_CACHEMAN_DONE = 5
  case DIFF_TREES_DONE = 7
  case DIFF_TREES_FAILED = 8
  case DIFF_TREES_CANCELLED = 9
  case SYNC_GDRIVE_CHANGES = 10
  case DOWNLOAD_ALL_GDRIVE_META = 11
  case COMMAND_COMPLETE = 12
  case GENERATE_MERGE_TREE_DONE = 13
  case GENERATE_MERGE_TREE_FAILED = 14
  case COMPLETE_MERGE = 15

  // --- Tree actions: requests ---
  case CALL_EXIFTOOL = 20
  case CALL_EXIFTOOL_LIST = 21
  case SHOW_IN_NAUTILUS = 22
  case CALL_XDG_OPEN = 23
  case EXPAND_AND_SELECT_NODE = 24
  case EXPAND_ALL = 25
  case DOWNLOAD_FROM_GDRIVE = 26
  case DELETE_SINGLE_FILE = 27
  case DELETE_SUBTREE = 28
  case SET_ROWS_CHECKED = 29
  case SET_ROWS_UNCHECKED = 30
  case FILTER_UI_TREE = 33
  /**
   Requests that the central cache update the stats for all nodes in the given subtree.
   When done, the central cache will send the signal REFRESH_SUBTREE_STATS_DONE to notify the tree that it can redraw the displayed nodes
   */
  case SHUTDOWN_APP = 34
  case DEREGISTER_DISPLAY_TREE = 35

  // --- Tree actions: notifications ---
  /** Fired by the backend when it has begun to load a subtree from cache */
  case LOAD_SUBTREE_STARTED = 40
  /** Fired by the backend when it has finsished loading a subtree from cache */
  case LOAD_SUBTREE_DONE = 41
  case NODE_EXPANSION_TOGGLED = 42
  case NODE_EXPANSION_DONE = 43
  case DISPLAY_TREE_CHANGED = 44
  case GDRIVE_RELOADED = 45
  case NODE_UPSERTED = 46
  case NODE_REMOVED = 47
  /** Sent by FE and received by the BE */
  case EXIT_DIFF_MODE = 49
  case ERROR_OCCURRED = 50
  case REFRESH_SUBTREE_STATS_DONE = 51
  case REFRESH_SUBTREE_STATS_COMPLETELY_DONE = 52
  /** Indicates that the central cache has updated the stats for the subtree, and the subtree should redraw the nodes */
  case DOWNLOAD_FROM_GDRIVE_DONE = 53
  /** This is fired by the UI when it has finished populating the UI tree */
  case POPULATE_UI_TREE_DONE = 54

  /** A Device was added or updated (includes the relevant Device in the msg) */
  case DEVICE_UPSERTED = 55

  case DRAG_AND_DROP = 60
  case DRAG_AND_DROP_DIRECT = 61

  case TREE_SELECTION_CHANGED = 70

  /** All components should listen for this */
  case TOGGLE_UI_ENABLEMENT = 80

  case PAUSE_OP_EXECUTION = 90
  case RESUME_OP_EXECUTION = 91
  case OP_EXECUTION_PLAY_STATE_CHANGED = 92

  // --- Progress bar ---
  case START_PROGRESS_INDETERMINATE = 100
  case START_PROGRESS = 101
  case SET_PROGRESS_TEXT = 102
  case PROGRESS_MADE = 103
  case STOP_PROGRESS = 104

  // --- Status bar ---
  case SET_STATUS = 105

  // --- Only used by SwiftUI ---
  case CANCEL_ALL_EDIT_ROOT = 200
  case CANCEL_OTHER_EDIT_ROOT = 201
}

// --- Sender identifiers ---
let ID_MAIN_WINDOW = "main_win"
let ID_LEFT_TREE = "left_tree"
let ID_RIGHT_TREE = "right_tree"
let ID_MERGE_TREE = "merge_tree"
let ID_GDRIVE_DIR_SELECT = "gdrive_dir_select"
let ID_GLOBAL_CACHE = "global_cache"
let ID_COMMAND_EXECUTOR = "command-executor"
let ID_CENTRAL_EXEC = "central-executor"
let ID_GDRIVE_POLLING_THREAD = "gdrive_polling_thread"
let ID_BACKEND_CLIENT = "backend-client"
