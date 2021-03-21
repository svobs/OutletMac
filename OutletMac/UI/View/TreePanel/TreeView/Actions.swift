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
  let con: TreeControllable

  init(_ controller: TreeControllable) {
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
      if sn.node!.isDir {
        let guid = self.con.displayStore.guidFor(sn)
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
      let parentGUID = self.con.displayStore.guidFor(parentSN)
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
      do {
        let node = sender.nodeList[0]
        let url = try URL(fileURLWithPath: node.nodeIdentifier.getSinglePath())
        NSWorkspace.shared.activateFileViewerSelecting([url])
      } catch {
        self.con.reportException("Could not show in Finder", error)
      }
    }
  }

  @objc public func downloadFromGDrive(_ sender: MenuItemWithNodeList) {
    guard sender.nodeList.count > 0 else {
      return
    }

    let node = sender.nodeList[0]

    self.con.app.execAsync {
      do {
        try self.con.backend.downloadFileFromGDrive(nodeUID: node.uid, requestorID: self.treeID)
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

  @objc public func checkAll(_ sender: MenuItemWithSNList) {
    let snList: [SPIDNodePair] = sender.snList

    // TODO: UI work
  }

  @objc public func uncheckAll(_ sender: MenuItemWithSNList) {
    let snList: [SPIDNodePair] = sender.snList

    // TODO: UI work
  }

  @objc func deleteSubtree(_ sender: MenuItemWithNodeList) {
    var nodeUIDList: [UID] = []
    for node in sender.nodeList {
      nodeUIDList.append(node.uid)
    }
    self.confirmAndDeleteSubtrees(nodeUIDList)
  }

  public func openLocalFileWithDefaultApp(_ fullPath: String) {
    self.con.app.execAsync {
      let url = URL(fileURLWithPath: fullPath)
      NSWorkspace.shared.open(url)
    }
  }

  public func confirmAndDeleteSubtrees(_ uidList: [UID]) {
    var msg = "Are you sure you want to delete"
    var okText = "Delete"
    if uidList.count == 1 {
      // TODO: ideally I would like to print the name of the item, but it's really hard to get from here
      msg += " this item?"
    } else {
      msg += " these \(uidList.count) items?"
      okText = "Delete \(uidList.count) items"
    }

    guard self.con.app.confirmWithUserDialog("Confirm Delete", msg, okButtonText: okText, cancelButtonText: "Cancel") else {
      NSLog("DEBUG [\(treeID)] User cancelled delete")
      return
    }

    NSLog("DEBUG [\(treeID)] User confirmed delete of \(uidList.count) items")

    do {
      try self.con.backend.deleteSubtree(nodeUIDList: uidList)
    } catch {
      self.con.reportException("Failed to delete subtree", error)
    }
  }

}
