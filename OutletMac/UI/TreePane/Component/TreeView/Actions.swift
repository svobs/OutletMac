//
//  TreeActions.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/17.
//

import SwiftUI

class TreeActions {
  weak var con: TreePanelControllable!  // Need to set this in parent controller's start() method

  typealias ActionHandler = ([SPIDNodePair]) -> Void

  private var actionHandlerDict: [ActionID : ActionHandler] = [:]

  init() {
    actionHandlerDict = [
      .EXPAND_ALL: { snList in self.con.treeView?.expandAll(snList) },
      .REFRESH: self.refreshSubtree,
      .GO_INTO_DIR: self.goIntoDir,
      .SHOW_IN_FILE_EXPLORER: self.showInFinder,
      .OPEN_WITH_DEFAULT_APP: { snList in self.openLocalFileWithDefaultApp(snList[0].spid.getSinglePath()) },
      .DOWNLOAD_FROM_GDRIVE: { snList in self.downloadFileFromGDrive(snList[0].node) },

      .SET_ROWS_CHECKED: { snList in self.setChecked(snList, true) },
      .SET_ROWS_UNCHECKED: { snList in self.setChecked(snList, false) }
    ]
  }

  var treeID: String {
    return con.treeID
  }

  // Context Menu Actions
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  // For dynamic menus provided by the backend. Uses the actionID to determine what to do (either local action or call into the backend)
  @objc public func executeMenuAction(_ sender: GeneratedMenuItem) {
    if sender.menuItemMeta.targetGUIDList.count > 0 {
      // If GUIDs are present here, they were provided by the backend. Send them right back for execution - it will know what to do with them.

      // Special overrides for delete actions: we want to confirm with the user first
      switch (sender.menuItemMeta.actionID) {
      case .DELETE_SINGLE_FILE:
        if !confirmDelete(sender.snList[0]) {
          return
        }
      case .DELETE_SUBTREE, .DELETE_SUBTREE_FOR_SINGLE_DEVICE:
        if !confirmDelete(sender.menuItemMeta.targetGUIDList.count) {
          return
        }
      default:
          break
      }

      do {
        let treeAction = TreeAction(self.treeID, sender.menuItemMeta.actionID, sender.menuItemMeta.targetGUIDList, [])
        try self.con.backend.executeTreeAction(treeAction)
      } catch {
        self.con.reportException("Failed to execute action: \(sender.menuItemMeta.actionID)", error)
      }
      return
    }

    // No GUIDs? Must be a FE action. Look up its handler and execute it:
    guard let handler: ActionHandler = actionHandlerDict[sender.menuItemMeta.actionID] else {
      self.con.reportError("Internal error", "No handler found for action: \(sender.menuItemMeta.actionID)")
      return
    }
    handler(sender.snList)
  }

  private func refreshSubtree(_ snList: [SPIDNodePair]) {
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

  private func showInFinder(_ snList: [SPIDNodePair]) {
    guard snList.count > 0 else {
      return
    }

    let url = URL(fileURLWithPath: snList[0].spid.getSinglePath())
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  private func goIntoDir(_ snList: [SPIDNodePair]) {
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

  private func setChecked(_ snList: [SPIDNodePair], _ checked: Bool) {
    do {
      for sn in snList {
        try self.con.setChecked(sn.spid.guid, checked)
      }
    } catch {
      self.con.reportException("Error while toggling checkbox", error)
    }
  }

  // Reusable actions (public)
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  public func downloadFileFromGDrive(_ node: Node) {
    do {
      NSLog("DEBUG [\(self.con.treeID)] Going to download file from GDrive: \(node)")
      try self.con.backend.downloadFileFromGDrive(deviceUID: node.deviceUID, nodeUID: node.uid, requestorID: self.treeID)
    } catch {
      self.con.reportException("Failed to download file from Google Drive", error)
    }
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
