//
//  ObservableObjects.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/16.
//
import SwiftUI

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
