//
//  ObservableObjects.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/16.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI

/**
 The EnivornmentObject containing shared state for all UI components in the app
 */
class GlobalSettings: ObservableObject {
  @Published var isPlaying = false

  // Alert stuff:
  @Published var showingAlert = false
  @Published var alertTitle: String = "Alert" // placeholder msg
  @Published var alertMsg: String = "An unknown error occurred" // placeholder msg
  @Published var dismissButtonText: String = "Dismiss" // placeholder msg

  /**
   This method will cause an alert to be displayed in the ContentView.
   */
  func showAlert(title: String, msg: String, dismissButtonText: String = "Dismiss") {
    self.alertTitle = title
    self.alertMsg = msg
    self.dismissButtonText = dismissButtonText
    self.showingAlert = true
  }
}


/**
 CLASS SwiftTreeState

 Encapsulates *ONLY* the information required to redraw the SwiftUI views for a given DisplayTree.
 */
class SwiftTreeState: ObservableObject {
  @Published var isUIEnabled: Bool
  @Published var isRootExists: Bool
  @Published var isEditingRoot: Bool
  @Published var isManualLoadNeeded: Bool
  @Published var offendingPath: String?
  @Published var rootPath: String = ""
  @Published var statusBarMsg: String = ""

  init(isUIEnabled: Bool, isRootExists: Bool, isEditingRoot: Bool, isManualLoadNeeded: Bool, offendingPath: String?, rootPath: String) {
    self.isUIEnabled = isUIEnabled
    self.isRootExists = isRootExists
    self.isEditingRoot = isEditingRoot
    self.isManualLoadNeeded = isManualLoadNeeded
    self.offendingPath = offendingPath
    self.rootPath = rootPath
  }

  func updateFrom(_ newTree: DisplayTree) {
    self.rootPath = newTree.rootPath
    self.offendingPath = newTree.state.offendingPath
    self.isRootExists = newTree.rootExists
    self.isEditingRoot = false
    self.isManualLoadNeeded = newTree.needsManualLoad
  }

  static func from(_ tree: DisplayTree) -> SwiftTreeState {
    return SwiftTreeState(isUIEnabled: true, isRootExists: tree.rootExists, isEditingRoot: false, isManualLoadNeeded: tree.needsManualLoad,
                          offendingPath: tree.state.offendingPath, rootPath: tree.rootPath)
  }
}

/**
 CLASS SwiftFilterState

 See FilterCriteria class.
 Note that this class uses "isMatchCase", which is the inverse of FilterCriteria's "isIgnoreCase"
 */
class SwiftFilterState: ObservableObject {
  var onChangeCallback: FilterStateCallback? = nil

  @Published var searchQuery: String {
    didSet {
      NSLog("Search query changed: \(searchQuery)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var isMatchCase: Bool {
    didSet {
      NSLog("isMatchCase changed: \(isMatchCase)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }

  @Published var isTrashed: Ternary {
    didSet {
      NSLog("isTrashed changed: \(isTrashed)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var isShared: Ternary {
    didSet {
      NSLog("isShared changed: \(isShared)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var showAncestors: Bool {
    didSet {
      NSLog("showAncestors changed: \(showAncestors)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }

  init(onChangeCallback: FilterStateCallback? = nil, searchQuery: String, isMatchCase: Bool, isTrashed: Ternary, isShared: Ternary, showAncestors: Bool) {
    self.onChangeCallback = onChangeCallback
    self.searchQuery = searchQuery
    self.isMatchCase = isMatchCase
    self.isTrashed = isTrashed
    self.isShared = isShared
    self.showAncestors = showAncestors
  }

  func updateFrom(_ filter: FilterCriteria, onChangeCallback: FilterStateCallback? = nil) {
    self.onChangeCallback = onChangeCallback
    self.searchQuery = filter.searchQuery
    self.isMatchCase = !filter.isIgnoreCase
    self.isTrashed = filter.isTrashed
    self.isShared = filter.isShared
    self.showAncestors = filter.showSubtreesOfMatches
  }

  func toFilterCriteria() -> FilterCriteria {
    return FilterCriteria(searchQuery: searchQuery, isTrashed: isTrashed, isShared: isShared, isIgnoreCase: !isMatchCase, showSubtreesOfMatches: showAncestors)
  }

  static func from(_ filter: FilterCriteria, onChangeCallback: FilterStateCallback? = nil) -> SwiftFilterState {
    return SwiftFilterState(onChangeCallback: onChangeCallback, searchQuery: filter.searchQuery, isMatchCase: !filter.isIgnoreCase, isTrashed: filter.isTrashed, isShared: filter.isShared, showAncestors: filter.showSubtreesOfMatches)
  }
}

typealias FilterStateCallback = (SwiftFilterState) -> Void
