//
//  ObservableObjects.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/16.
//
import SwiftUI

/**
 The EnvironmentObject containing shared state for all UI components in the app
 */
class GlobalSettings: ObservableObject {
  @Published var isPlaying = false

  @Published var deviceList: [Device] = []

  @Published var mode: WindowMode = .BROWSING

  // Alert stuff:
  @Published var showingAlert = false
  @Published var alertTitle: String = "Alert" // placeholder msg
  @Published var alertMsg: String = "An unknown error occurred" // placeholder msg
  @Published var dismissButtonText: String = "Dismiss" // placeholder msg

  @Published var isUIEnabled: Bool = true

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
    NSLog("DEBUG Resetting settings")
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

class WindowState: ObservableObject {
  // These two values are calculated and stored so that the proper height of the OutlineView can be derived
  @Published var windowHeight: CGFloat = 0
  @Published var nonTreeViewHeight: CGFloat = 0

  func getTreeViewHeight() -> CGFloat {
//    NSLog("DEBUG getTreeViewHeight(): \(self.windowHeight) - \(self.nonTreeViewHeight)")
    return self.windowHeight - self.nonTreeViewHeight
  }

}


/**
 CLASS SwiftTreeState

 Encapsulates *ONLY* the information required to redraw the SwiftUI views for a given DisplayTree.
 */
class SwiftTreeState: ObservableObject {
  @Published var isRootExists: Bool
  @Published var isEditingRoot: Bool
  @Published var isManualLoadNeeded: Bool
  @Published var offendingPath: String?
  @Published var rootPathNonEdit: String = ""
  @Published var rootPath: String = ""
  @Published var rootDeviceUID: UID = NULL_UID
  @Published var statusBarMsg: String = ""
  @Published var treeType: TreeType = TreeType.NA
  @Published var hasCheckboxes: Bool

  init(isRootExists: Bool, isEditingRoot: Bool, isManualLoadNeeded: Bool, offendingPath: String?,
       rootPath: String, rootPathNonEdit: String, rootDeviceUID: UID, treeType: TreeType, hasCheckboxes: Bool) {
    self.isRootExists = isRootExists
    self.isEditingRoot = isEditingRoot
    self.isManualLoadNeeded = isManualLoadNeeded
    self.offendingPath = offendingPath
    self.rootPath = rootPath
    self.rootPathNonEdit = rootPathNonEdit
    self.rootDeviceUID = rootDeviceUID
    self.treeType = treeType
    self.hasCheckboxes = hasCheckboxes
  }

  func updateFrom(_ tree: DisplayTree) throws {
    self.rootPathNonEdit = tree.rootPath
    self.treeType = try tree.backend.nodeIdentifierFactory.getTreeType(for: tree.rootSPID.deviceUID)
    self.rootPath = tree.rootSPID.getSinglePath()
    self.offendingPath = tree.state.offendingPath
    self.isRootExists = tree.rootExists
    self.isEditingRoot = false
    self.isManualLoadNeeded = tree.needsManualLoad
    self.rootDeviceUID = tree.rootDeviceUID
    self.hasCheckboxes = tree.hasCheckboxes
  }

  static func from(_ tree: DisplayTree) throws -> SwiftTreeState {
    let treeType = try tree.backend.nodeIdentifierFactory.getTreeType(for: tree.rootSPID.deviceUID)
    return SwiftTreeState(isRootExists: tree.rootExists, isEditingRoot: false, isManualLoadNeeded: tree.needsManualLoad,
                          offendingPath: tree.state.offendingPath, rootPath: tree.rootSPID.getSinglePath(),
                          rootPathNonEdit: tree.rootPath, rootDeviceUID: tree.rootDeviceUID, treeType: treeType, hasCheckboxes: tree.hasCheckboxes)
  }
}

/**
 CLASS SwiftFilterState

 See FilterCriteria class.
 Note that this class uses "isMatchCase", which is the inverse of FilterCriteria's "isIgnoreCase"
 */
class SwiftFilterState: ObservableObject, CustomStringConvertible {
  // See: TreePanelController.onFilterChanged()
  var onChangeCallback: FilterStateCallback? = nil

  @Published var searchQuery: String {
    didSet {
      NSLog("DEBUG Search query changed: \(searchQuery)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var isMatchCase: Bool {
    didSet {
      NSLog("DEBUG isMatchCase changed: \(isMatchCase)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }

  @Published var isTrashed: Ternary {
    didSet {
      NSLog("DEBUG isTrashed changed: \(isTrashed)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var isShared: Ternary {
    didSet {
      NSLog("DEBUG isShared changed: \(isShared)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }
  @Published var showAncestors: Bool {
    didSet {
      NSLog("DEBUG showAncestors changed: \(showAncestors)")
      if onChangeCallback != nil {
        onChangeCallback!(self)
      }
    }
  }

  func isFlatList() -> Bool {
    let hasCriteria = self.hasCriteria()
    let notShowAncestors = !self.showAncestors
    return hasCriteria && notShowAncestors
  }

  func hasCriteria() -> Bool {
    return searchQuery != "" || isTrashed != .NOT_SPECIFIED || isShared != .NOT_SPECIFIED
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
    self.showAncestors = filter.showAncestors
  }

  func toFilterCriteria() -> FilterCriteria {
    return FilterCriteria(searchQuery: searchQuery, isTrashed: isTrashed, isShared: isShared, isIgnoreCase: !isMatchCase, showAncestors: showAncestors)
  }

  static func from(_ filter: FilterCriteria, onChangeCallback: FilterStateCallback? = nil) -> SwiftFilterState {
    return SwiftFilterState(onChangeCallback: onChangeCallback, searchQuery: filter.searchQuery, isMatchCase: !filter.isIgnoreCase, isTrashed: filter.isTrashed, isShared: filter.isShared, showAncestors: filter.showAncestors)
  }

  var description: String {
    return "SwiftFilterState(q=\"\(searchQuery)\" trashed=\(isTrashed) shared=\(isShared) isMatchCase=\(isMatchCase) showAncestors=\(showAncestors))"
  }
}

typealias FilterStateCallback = (SwiftFilterState) -> Void


struct MyHeightPreferenceData: Equatable {
  var col0: [String: CGFloat] = [:]
  var col1: [String: CGFloat] = [:]

  init(name: String, col: UInt, height: CGFloat) {
    if col == 0 {
      col0[name] = height
    } else if col == 1 {
      col1[name] = height
    }
  }

  init() {
  }
}


struct MyHeightPreferenceKey: PreferenceKey {
  /**
   Value: is a typealias that indicates what type of information we want to expose through the preference.
   In this example you see that we are using an array of MyHeightPreferenceData. I will get to that in a minute.
   */
  typealias Value = MyHeightPreferenceData

  /**
   When a preference key value has not been set explicitly, SwiftUI will use this defaultValue.
   */
  static var defaultValue: MyHeightPreferenceData = MyHeightPreferenceData()

  /**
   reduce: This is a static function that SwiftUI will use to merge all the key values found in the view tree. Normally, you use it to accumulate all the values it receives, but you can do whatever you want. In our case, when SwiftUI goes through the tree, it will collect the preference key values and store them together in a single array, which we will be able to access later. You should know that Values are supplied to the reduce function in view-tree order. We’ll come back to that in another example, as the order is not relevant here.
   */
  static func reduce(value: inout MyHeightPreferenceData, nextValue: () -> MyHeightPreferenceData) {
    let next = nextValue()
    for (name, size) in next.col0 {
      value.col0[name] = size
    }
    for (name, size) in next.col1 {
      value.col1[name] = size
    }
//    NSLog("REDUCE: \(value.col0), \(value.col1)")
  }
}


struct ContentAreaPrefData: Equatable {
  var height: CGFloat
}


struct ContentAreaPrefKey: PreferenceKey {
  typealias Value = ContentAreaPrefData

  /**
   When a preference key value has not been set explicitly, SwiftUI will use this defaultValue.
   */
  static var defaultValue: ContentAreaPrefData = ContentAreaPrefData(height: 0)

  /**
   reduce: This is a static function that SwiftUI will use to merge all the key values found in the view tree. Normally, you use it to accumulate all the values it receives, but you can do whatever you want. In our case, when SwiftUI goes through the tree, it will collect the preference key values and store them together in a single array, which we will be able to access later. You should know that Values are supplied to the reduce function in view-tree order. We’ll come back to that in another example, as the order is not relevant here.
   */
  static func reduce(value: inout ContentAreaPrefData, nextValue: () -> ContentAreaPrefData) {
    value = nextValue()
    NSLog("HEIGHT OF CONTENT AREA: \(value.height)")
  }
}
