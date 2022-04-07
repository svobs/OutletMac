//
//  TreeActions.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/17.
//

import AppKit

/*
 A set of handlers for TreeAction, each of which is identified by an ActionID.
 See: TreeAction.swift
 See:
 */
class TreeActions {
  weak var con: TreeControllable!  // Need to set this in parent controller's start() method

  private typealias TreeActionHandler = (TreeAction) -> Void

  private var actionHandlerDict: [ActionID : TreeActionHandler] = [:]

  init() {
    actionHandlerDict = [
      .EXPAND_ALL: { action in
        DispatchQueue.main.async {
          self.con.treeView?.expandAll(action.targetGUIDList)
        }
      },
      .REFRESH: { action in self.refreshSubtree(action.targetGUIDList) },
      .GO_INTO_DIR: { action in self.goIntoDir(action.targetGUIDList) },
      .SHOW_IN_FILE_EXPLORER: { action in self.showInFinder(action.targetGUIDList) },
      .OPEN_WITH_DEFAULT_APP: { action in self.openLocalFileWithDefaultAppForNodeList(action.targetNodeList) },
      .DOWNLOAD_FROM_GDRIVE: { action in self.downloadFileListFromGDrive(action.targetNodeList) },

      .SET_ROWS_CHECKED: { action in self.setChecked(action.targetGUIDList, true) },
      .SET_ROWS_UNCHECKED: { action in self.setChecked(action.targetGUIDList, false) },

      .EXPAND_ROWS: {action in
        DispatchQueue.main.async {
          self.con.treeView?.expand(action.targetGUIDList, isAlreadyPopulated: false)
        }
      },
      .COLLAPSE_ROWS: { action in
        DispatchQueue.main.async {
          self.con.treeView?.collapse(action.targetGUIDList)
        }
      },
      .DELETE_SINGLE_FILE: { action in
        guard let sn = self.con.displayStore.getSN(action.targetGUIDList[0]) else {
          self.con.reportError("Internal error", "Could not find node in DisplayStore for: \(action.targetGUIDList[0])")
          return
        }
        if self.confirmDelete(sn) {
          self.executeActionViaBackend(action)
        }
      },
      .DELETE_SUBTREE_FOR_SINGLE_DEVICE: { action in
        if self.confirmDelete(action.targetGUIDList.count) {
          self.executeActionViaBackend(action)
        }
      },
      .DELETE_SUBTREE: { action in
        if self.confirmDelete(action.targetGUIDList.count) {
          self.executeActionViaBackend(action)
        }
      }
    ]
  }

  var treeID: String {
    return con.treeID
  }

  // Context Menu Actions
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  // For dynamic menus provided by the backend. Uses the actionID to determine what to do (either local action or call into the backend)
  @objc public func executeMenuAction(_ sender: GeneratedMenuItem) {
    executeTreeAction(TreeAction(self.con.treeID, sender.menuItemMeta.actionType, sender.menuItemMeta.targetGUIDList, []))
  }

  func executeTreeAction(_ action: TreeAction) {
    NSLog("DEBUG [\(self.con.treeID)] Executing action \(action.actionType) guidList=\(action.targetGUIDList) nodeList=\(action.targetNodeList.count)")

    switch action.actionType {
    case .BUILTIN(let actionID):
      // First see if we can handle this in the FE:
      if let handler: TreeActionHandler = actionHandlerDict[actionID] {
        NSLog("DEBUG [\(self.con.treeID)] Calling local handler for action: \(actionID)")
        handler(action)
        return
      }
    case .CUSTOM:
      break
    }

    executeActionViaBackend(action)
  }

  private func executeActionViaBackend(_ action: TreeAction) {
    do {
      try self.con.backend.executeTreeAction(action)
    } catch {
      self.con.reportException("Failed to execute action: \(action)", error)
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

    NSLog("DEBUG [\(self.con.treeID)] goIntoDir(): \(spid)")

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

  public func downloadFileListFromGDrive(_ nodeList: [TNode]) {
    do {
      for node in nodeList {
        NSLog("DEBUG [\(self.con.treeID)] Going to download file from GDrive: \(node)")
        try self.con.backend.downloadFileFromGDrive(deviceUID: node.deviceUID, nodeUID: node.uid, requestorID: self.treeID)
      }
    } catch {
      self.con.reportException("Failed to download file from Google Drive", error)
    }
  }

  public func openLocalFileWithDefaultAppForNodeList(_ nodeList: [TNode]) {
    for node in nodeList {
      if node.treeType == .LOCAL_DISK {
        self.openLocalFileWithDefaultApp(node.firstPath)
      }
    }
  }

  public func openLocalFileWithDefaultApp(_ fullPath: String) {
    NSLog("DEBUG [\(self.con.treeID)] Opening file with default app: '\(fullPath)'")
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

  public func confirmAndDeleteSubtrees(_ nodeList: [TNode]) {
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
