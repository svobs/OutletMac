//
//  TreeActions.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/17.
//

import SwiftUI
import LinkedList

// Context Menu Actions
// ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼
class TreeActions {
  let con: TreePanelControllable

  init(_ controller: TreePanelControllable) {
    self.con = controller
  }

  var treeID: String {
    return con.treeID
  }

  @objc public func expandAll(_ sender: MenuItemWithSNList) {
    guard sender.snList.count > 0 else {
      return
    }

    guard let outlineView = self.con.treeView?.outlineView else {
      return
    }

    // contains items which were just expanded and need their children examined
    var queue = LinkedList<SPIDNodePair>()

    func process(_ sn: SPIDNodePair) {
      if sn.node.isDir {
        let guid = sn.spid.guid
        if !outlineView.isItemExpanded(guid) {
          outlineView.animator().expandItem(guid)
        }
        queue.append(sn)
      }
    }

    for sn in sender.snList {
      process(sn)
    }

    while !queue.isEmpty {
      let parentSN = queue.popFirst()!
      let parentGUID = parentSN.spid.guid
      for sn in self.con.displayStore.getChildList(parentGUID) {
        process(sn)
      }
    }

  }

  @objc public func refreshSubtree(_ sender: MenuItemWithSNList) {
    guard sender.snList.count > 0 else {
      return
    }
    let nodeIdentifier = sender.snList[0].spid
    do {
      try self.con.backend.enqueueRefreshSubtreeTask(nodeIdentifier: nodeIdentifier, treeID: self.treeID)
    } catch {
      self.con.reportException("Failed to refresh subtree", error)
    }
  }

  @objc public func showInFinder(_ sender: MenuItemWithNodeList) {
    guard sender.nodeList.count > 0 else {
      return
    }

    self.con.app.execAsync {
      let node = sender.nodeList[0]
      let url = URL(fileURLWithPath: node.nodeIdentifier.getSinglePath())
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }
  }

  @objc public func downloadFromGDrive(_ sender: MenuItemWithNodeList) {
    guard sender.nodeList.count > 0 else {
      return
    }

    let node = sender.nodeList[0]

    self.con.app.execAsync {
      do {
        try self.con.backend.downloadFileFromGDrive(deviceUID: node.deviceUID, nodeUID: node.uid, requestorID: self.treeID)
      } catch {
        self.con.reportException("Failed to download file from Google Drive", error)
      }
    }
  }

  @objc public func openFile(_ sender: MenuItemWithSNList) {
    guard sender.snList.count > 0 else {
      return
    }

    let sn = sender.snList[0]

    self.openLocalFileWithDefaultApp(sn.spid.getSinglePath())
  }

  @objc public func goIntoDir(_ sender: MenuItemWithSNList) {
    guard sender.snList.count > 0 else {
      return
    }

    let sn = sender.snList[0]

    self.con.app.execAsync {
      do {
        let _ = try self.con.app.backend.createDisplayTreeFromSPID(treeID: self.treeID, spid: sn.spid)
      } catch {
        self.con.reportException("Failed to change tree root directory", error)
      }
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

  @objc public func checkAll(_ sender: MenuItemWithSNList) {
    let snList: [SPIDNodePair] = sender.snList
    self.setChecked(snList, true)
  }

  @objc public func uncheckAll(_ sender: MenuItemWithSNList) {
    let snList: [SPIDNodePair] = sender.snList
    self.setChecked(snList, false)
  }

  @objc func deleteSubtree(_ sender: MenuItemWithSNList) {
    self.confirmAndDeleteSubtrees(sender.snList)
  }

  public func openLocalFileWithDefaultApp(_ fullPath: String) {
    self.con.app.execAsync {
      // FIXME: need permissions
      let url = URL(fileURLWithPath: fullPath)
      NSWorkspace.shared.open(url)
    }
  }

  public func confirmAndDeleteSubtrees(_ snList: [SPIDNodePair]) {
    if snList.count == 0 {
      self.con.reportError("Cannot Delete", "No items are selected!")
      return
    }

    var msg = "Are you sure you want to delete "
    var okText = "Delete"
    if snList.count == 1 {
      msg += "\"\(snList[0].node.name)\"?"
    } else {
      msg += "these \(snList.count) items?"
      okText = "Delete \(snList.count) items"
    }

    guard self.con.app.confirmWithUserDialog("Confirm Delete", msg, okButtonText: okText, cancelButtonText: "Cancel") else {
      NSLog("DEBUG [\(treeID)] User cancelled delete")
      return
    }

    NSLog("DEBUG [\(treeID)] User confirmed delete of \(snList.count) items")

    var nodeUIDList: [UID] = []
    for sn in snList {
      nodeUIDList.append(sn.node.uid)
    }

    do {
      let deviceUID = snList[0].spid.deviceUID
      try self.con.backend.deleteSubtree(deviceUID: deviceUID, nodeUIDList: nodeUIDList)
    } catch {
      self.con.reportException("Failed to delete subtree", error)
    }
  }

}
