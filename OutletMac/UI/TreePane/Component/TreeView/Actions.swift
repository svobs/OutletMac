//
//  TreeActions.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/17.
//

import SwiftUI

class TreeActions {
  weak var con: TreePanelControllable!  // Need to set this in parent controller's start() method

  typealias ActionHandler = (TreeAction) -> Void

  private var actionHandlerDict: [ActionID : ActionHandler] = [:]

  init() {
    actionHandlerDict = [
      .EXPAND_ALL: { action in self.con.treeView?.expandAll(action.targetGUIDList) },
      .REFRESH: { action in self.refreshSubtree(action.targetGUIDList) },
      .GO_INTO_DIR: { action in self.goIntoDir(action.targetGUIDList) },
      .SHOW_IN_FILE_EXPLORER: { action in self.showInFinder(action.targetGUIDList) },
      .OPEN_WITH_DEFAULT_APP: { action in self.openLocalFileWithDefaultAppForGUID(action.targetGUIDList[0]) },
      .DOWNLOAD_FROM_GDRIVE: { action in self.downloadFileFromGDrive(action.targetGUIDList[0]) },

      .SET_ROWS_CHECKED: { action in self.setChecked(action.targetGUIDList, true) },
      .SET_ROWS_UNCHECKED: { action in self.setChecked(action.targetGUIDList, false) },

      .EXPAND_ROWS: {action in self.con.treeView?.expand(action.targetGUIDList, isAlreadyPopulated: false)},
      .COLLAPSE_ROWS: {action in self.con.treeView?.collapse(action.targetGUIDList)}
    ]
  }

  var treeID: String {
    return con.treeID
  }

  // Context Menu Actions
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  // For dynamic menus provided by the backend. Uses the actionID to determine what to do (either local action or call into the backend)
  @objc public func executeMenuAction(_ sender: GeneratedMenuItem) {
    executeTreeAction(TreeAction(self.con.treeID, sender.menuItemMeta.actionID, sender.menuItemMeta.targetGUIDList, []))
  }

  func executeTreeAction(_ action: TreeAction) {
    // First see if we can handle this in the FE:
    if let handler: ActionHandler = actionHandlerDict[action.actionID] {
      handler(action)
      return
    }

    // Special overrides for delete actions: we want to confirm with the user first
    switch (action.actionID) {
    case .DELETE_SINGLE_FILE:
      guard let sn = self.con.displayStore.getSN(action.targetGUIDList[0]) else {
        self.con.reportError("Internal error", "Could not find node in DisplayStore for: \(action.targetGUIDList[0])")
        return
      }
      if !confirmDelete(sn) {
        return
      }
    case .DELETE_SUBTREE, .DELETE_SUBTREE_FOR_SINGLE_DEVICE:
      if !confirmDelete(action.targetGUIDList.count) {
        return
      }
    default:
      break
    }

    do {
      let treeAction = TreeAction(self.treeID, action.actionID, action.targetGUIDList, [])
      try self.con.backend.executeTreeAction(treeAction)
    } catch {
      self.con.reportException("Failed to execute action: \(action.actionID)", error)
    }
  }

  private func refreshSubtree(_ guidList: [GUID]) {
    let snList = self.con.displayStore.getSNList(guidList)
    guard snList.count > 0 else {
      return
    }
    let nodeIdentifier = snList[0].spid
    do {
      try self.con.backend.enqueueRefreshSubtreeTask(nodeIdentifier: nodeIdentifier, treeID: self.treeID)
    } catch {
      self.con.reportException("Failed to refresh subtree", error)
    }
  }

  private func showInFinder(_ guidList: [GUID]) {
    let snList = self.con.displayStore.getSNList(guidList)
    guard snList.count > 0 else {
      return
    }

    let url = URL(fileURLWithPath: snList[0].spid.getSinglePath())
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  private func goIntoDir(_ guidList: [GUID]) {
    let snList = self.con.displayStore.getSNList(guidList)
    guard snList.count > 0 else {
      return
    }

    let spid = snList[0].spid

    NSLog("DEBUG goIntoDir(): \(spid)")

    self.con.clearTreeAndDisplayMsg(LOADING_MESSAGE, .ICON_LOADING)

    do {
      let _ = try self.con.app.backend.createDisplayTreeFromSPID(treeID: self.treeID, spid: spid)
    } catch {
      self.con.reportException("Failed to change tree root directory", error)
    }
  }

  private func setChecked(_ guidList: [GUID], _ checked: Bool) {
    do {
      for guid in guidList {
        try self.con.setChecked(guid, checked)
      }
    } catch {
      self.con.reportException("Error while toggling checkbox", error)
    }
  }

  // Reusable actions (public)
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  public func downloadFileFromGDrive(_ guid: GUID) {
    do {
      let sn = self.con.displayStore.getSN(guid)!
      let node = sn.node
      NSLog("DEBUG [\(self.con.treeID)] Going to download file from GDrive: \(node)")
      try self.con.backend.downloadFileFromGDrive(deviceUID: node.deviceUID, nodeUID: node.uid, requestorID: self.treeID)
    } catch {
      self.con.reportException("Failed to download file from Google Drive", error)
    }
  }

  public func openLocalFileWithDefaultAppForGUID(_ guid: GUID) {
    guard let sn = self.con.displayStore.getSN(guid) else {
      self.con.reportError("Internal error", "Could not find node in DisplayStore for: \(guid)")
      return
    }
    self.openLocalFileWithDefaultApp(sn.spid.getSinglePath())
  }

  public func openLocalFileWithDefaultApp(_ fullPath: String) {
    // FIXME: need permissions
    let url = URL(fileURLWithPath: fullPath)
    NSWorkspace.shared.open(url)
  }

  func confirmDelete(_ singleSN: SPIDNodePair) -> Bool {
    return self.confirmDelete("\"\(singleSN.node.name)\"", okText: "Delete")
  }

  func confirmDelete(_ count: Int) -> Bool {
    return self.confirmDelete("these \(count) items", okText: "Delete \(count) items")
  }

  func confirmDelete(_ itemDescription: String, okText: String) -> Bool {
    let msg = "Are you sure you want to delete \(itemDescription)?"

    guard self.con.app.confirmWithUserDialog("Confirm Delete", msg, okButtonText: okText, cancelButtonText: "Cancel") else {
      NSLog("DEBUG [\(treeID)] User cancelled delete")
      return false
    }

    NSLog("DEBUG [\(treeID)] User confirmed delete of \(itemDescription)")
    return true
  }

  public func confirmAndDeleteSubtrees(_ nodeList: [Node]) {
    if !confirmDelete(nodeList.count) {
      return
    }

    var nodeUIDList: [UID] = []
    for node in nodeList {
      nodeUIDList.append(node.uid)
    }

    do {
      let deviceUID = nodeList[0].deviceUID
      try self.con.backend.deleteSubtree(deviceUID: deviceUID, nodeUIDList: nodeUIDList)
    } catch {
      self.con.reportException("Failed to delete subtree", error)
    }
  }

}
