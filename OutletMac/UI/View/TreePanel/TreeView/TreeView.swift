import Cocoa
import AppKit
import SwiftUI
import Foundation
import LinkedList

/**
 TreeView: extra layer of TreeView to specify layout
 */
struct TreeView: View {
  let con: TreePanelControllable
  @EnvironmentObject var settings: GlobalSettings
  @ObservedObject var swiftTreeState: SwiftTreeState
  @ObservedObject var heightTracking: HeightTracking

  init(controller: TreePanelControllable, _ heightTracking: HeightTracking) {
    self.con = controller
    self.swiftTreeState = self.con.swiftTreeState
    self.heightTracking = heightTracking
  }

  private func makeTreeView() -> some View {
      TreeViewRepresentable(controller: self.con)
        .padding(.top)
        .frame(minWidth: 200,
               maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               // A redraw of this view should be triggered when either of these values are changed:
               minHeight: heightTracking.getTreeViewHeight(),
               maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               alignment: .topLeading)
  }

  var body: some View {
    HStack {
      // Here we really want to just wipe out the NSOutlineView and rebuild it from scratch if the
      // value of 'hasCheckboxes' changes. This accomplishes that in an almost-clean way:
      if swiftTreeState.hasCheckboxes {
        makeTreeView()
      } else {
        makeTreeView()
      }
    }
    .frame(alignment: .topLeading)
  }
}

/**
 TreeViewRepresentable: SwiftUI wrapper for NSOutlineView
 */
struct TreeViewRepresentable: NSViewControllerRepresentable {
  let con: TreePanelControllable

  init(controller: TreePanelControllable) {
    self.con = controller
  }

  func makeNSViewController(context: Context) -> TreeViewController {
    let treeViewController = TreeViewController()
    treeViewController.con = self.con
    return treeViewController
  }
  
  func updateNSViewController(_ nsViewController: TreeViewController, context: Context) {
    // TODO: apply updates here
    NSLog("DEBUG [\(self.con.treeID)] TreeView update requested!")
    return
  }
}

// TreeViewController
// ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

/*
 See: https://www.appcoda.com/macos-programming-nsoutlineview/
 See: https://stackoverflow.com/questions/45373039/how-to-program-a-nsoutlineview
 */
final class TreeViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuDelegate {
  // Cannot override init(), but this must be set manually before loadView() is called
  var con: TreePanelControllable! = nil

  let outlineView = NSOutlineView()
  var expandContractListenersEnabled: Bool = true

  var displayStore: DisplayStore {
    return self.con.displayStore
  }

  var treeID: String {
    return con.treeID
  }

  override func keyDown(with theEvent: NSEvent) {
    // Enable key events
    interpretKeyEvents([theEvent])
  }

  /**
   Delete key pressed: confirm delete, then delete all selected items
   */
  override func deleteBackward(_ sender: Any?) {
    let selectedRowIndexes: IndexSet = outlineView.selectedRowIndexes
    if selectedRowIndexes.isEmpty {
      return
    }

    outlineView.beginUpdates()
    defer {
      outlineView.endUpdates()
    }

    let selectedUIDList = Array(self.getSelectedUIDs())
    self.con.treeActions.confirmAndDeleteSubtrees(selectedUIDList)
  }


  @objc func doubleClickedItem(_ sender: NSOutlineView) {
    let item = sender.item(atRow: sender.clickedRow)

    let guid = itemToGUID(item)
    guard let sn = self.displayStore.getSN(guid) else {
      return
    }

    if sn.node!.isDir {
      // Is dir -> toggle expand/collapse

      if outlineView.isItemExpanded(guid) {
        NSLog("DEBUG [\(treeID)] User double-clicked: collapsing item: \(guid)")
        outlineView.animator().collapseItem(guid, collapseChildren: true)
      } else {
        NSLog("DEBUG [\(treeID)] User double-clicked: expanding item: \(guid)")
        outlineView.animator().expandItem(guid)
      }

    } else {
      if sn.spid.treeType == .LOCAL_DISK {
        NSLog("DEBUG [\(treeID)] User double-clicked: opening local file with default app: \(sn.spid.getSinglePath())")
        self.con.treeActions.openLocalFileWithDefaultApp(sn.spid.getSinglePath())
      } else if sn.spid.treeType == .GDRIVE {
        // TODO: download from GDrive and open downloaded file
        NSLog("DEBUG [\(treeID)] User double-clicked on Google Drive node: \(sn.spid)")
      } else {
        NSLog("DEBUG [\(treeID)] User double-clicked on node: \(sn.spid)")
      }
    }
  }

  // NSViewController methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  override func loadView() {
    // connect to controller
    NSLog("DEBUG [\(treeID)] loadView(): setting TreeViewController in TreeController")
    self.con.connectTreeView(self)

    view = NSView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    OutlineViewFactory.buildOutlineView(self.view, outlineView: outlineView)

    outlineView.allowsMultipleSelection = self.con.allowMultipleSelection

    // Hook up double-click handler
    outlineView.doubleAction = #selector(doubleClickedItem)

    outlineView.delegate = self
    outlineView.dataSource = self
    outlineView.menu = self.initContextMenu()
  }

  // DataSource methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Returns a GUID corresponding to the item with the given parameters

   1. You must give each row a unique identifier, referred to as `item` by the outline view.
   2. For top-level rows, we use the values in the `keys` array
   3. item == nil means it's the "root" row of the outline view, which is not visible
   */
  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if let child  = displayStore.getChild(itemToGUID(item), index) {
      return child.spid.guid
    } else {
      return TOPMOST_GUID
    }
  }

  /**
  // Tell Apple how many children each row has.
  */
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    return displayStore.getChildList(itemToGUID(item)).count
  }

  /**
   Tell whether the row is expandable
   */
  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    // TODO: in the future, we'll want to download the contents of each child directory so that we
    // can tell whether it is expandable (or at least download a flag saying it has at least 1 child)

    return displayStore.isDir(itemToGUID(item)) && !self.con.swiftFilterState.isFlatList()
  }

  // NSOutlineViewDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Make cell view.
   From NSOutlineViewDelegate
   */
  public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let identifier = tableColumn?.identifier else { return nil }

    guard let guid = item as? GUID else {
      NSLog("ERROR [\(treeID)] viewForTableColumn(): not a GUID: \(item)")
      return nil
    }

    if guid == TOPMOST_GUID {
      // TODO: why is this happening for change trees?
      NSLog("ERROR [\(treeID)] Should not be creating a row for the root GUID!")
      return nil
    }

    return CellFactory.upsertCellToOutlineView(self, identifier, guid)
  }

  /**
   Post Selection Change
   From NSOutlineViewDelegate
  */
  func outlineViewSelectionDidChange(_ notification: Notification) {
    let guidSet: Set<GUID> = self.getSelectedGUIDs()
    NSLog("DEBUG [\(treeID)] User selected GUIDs: \(guidSet)")

    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        try self.con.backend.setSelectedRowSet(guidSet, self.treeID)
      } catch {
        // Not a serious error: don't show to user
        NSLog("Failed to report node selection: \(error)")
      }
    }

    var snList: [SPIDNodePair] = []

    for guid in self.getSelectedGUIDs() {
      if let sn = self.displayStore.getSN(guid) {
        snList.append(sn)
      }
    }
    self.con.dispatcher.sendSignal(signal: .TREE_SELECTION_CHANGED, senderID: self.con.treeID, ["sn_list": snList])
  }

  /**
   Pre Row Expand
   From NSOutlineViewDelegate
   */
  func outlineViewItemWillExpand(_ notification: Notification) {
    guard self.expandContractListenersEnabled else {
      return
    }

    guard let parentGUID: GUID = getKey(notification) else {
      return
    }

    guard let parentSN: SPIDNodePair = self.displayStore.getSN(parentGUID) else {
      return
    }

    NSLog("DEBUG [\(treeID)] User expanded node \(parentGUID)")

    do {
      let childSNList = try self.con.backend.getChildList(parentSPID: parentSN.spid, treeID: self.treeID, maxResults: MAX_NUMBER_DISPLAYABLE_CHILD_NODES)

      outlineView.beginUpdates()
      defer {
        outlineView.endUpdates()
      }
      self.displayStore.putChildList(parentSN, childSNList)
      self.outlineView.reloadItem(parentGUID, reloadChildren: true)
    } catch OutletError.maxResultsExceeded(let actualCount) {
      self.con.appendEphemeralNode(parentSN, "ERROR: too many items to display (\(actualCount))")
    } catch {
      self.con.reportException("Failed to expand node", error)
    }
  }

  /**
   Pre Row Collapse
   From NSOutlineViewDelegate
   */
  func outlineViewItemWillCollapse(_ notification: Notification) {
    guard let parentGUID: GUID = getKey(notification) else {
      return
    }
    NSLog("DEBUG [\(treeID)] User collapsed node \(parentGUID)")

    do {
      // Tell BE to remove the GUID from its peresisted state of expanded rows. (No need to make a
      // similar call when the row is expanded; the BE does this automatically when getChildList() called)
      NSLog("DEBUG [\(treeID)] Reporting collapsed node to BE: \(parentGUID)")
      try self.con.backend.removeExpandedRow(parentGUID, self.treeID)
    } catch {
      NSLog("ERROR [\(treeID)] Failed to report collapsed node to BE: \(error)")
    }
  }

  // Utility methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func itemToGUID(_ item: Any?) -> GUID {
    if item == nil {
      return TOPMOST_GUID
    } else {
      return item as! GUID
    }
  }

  func getSelectedUIDs() -> Set<UID> {
    var uidSet = Set<UID>()
    for selectedRow in outlineView.selectedRowIndexes {
      if let item = outlineView.item(atRow: selectedRow) {
        if let guid = item as? GUID {
          if let sn = displayStore.getSN(guid) {
            uidSet.insert(sn.node!.uid)
          }
        }
      }
    }
    return uidSet
  }

  // Note: currently this will include any selected ephemeral nodes. It's currently not worth the cycles
  // to weed them out.
  func getSelectedGUIDs() -> Set<GUID> {
    var guidSet = Set<GUID>()
    for selectedRow in outlineView.selectedRowIndexes {
      if let item = outlineView.item(atRow: selectedRow) {
        if let guid = item as? GUID {
          guidSet.insert(guid)
        }
      }
    }
    return guidSet
  }

  private func getKey(_ notification: Notification) -> GUID? {
    guard let item = notification.userInfo?["NSObject"] else {
      NSLog("ERROR [\(treeID)] getKey(): no item")
      return nil
    }

    guard let guid = item as? GUID else {
      NSLog("ERROR [\(treeID)] getKey(): not a GUID: \(item)")
      return nil
    }
    return guid
  }

  // NOTE: this MUST be called on the main thread!
  func getIndexSetFor(_ guid: GUID) -> IndexSet {
    let index = self.outlineView.row(forItem: guid)

    var indexSet = IndexSet()
    guard index >= 0 else {
      NSLog("ERROR [\(self.treeID)] Index not found for: \(guid). Returning empty index set")
      return indexSet
    }

    indexSet.insert(index)
    return indexSet
  }

  func selectSingleSPID(_ spid: SPID) {
    let guid = spid.guid

    DispatchQueue.main.async {
      let indexSet = self.getIndexSetFor(guid)
      if !indexSet.isEmpty {
        NSLog("DEBUG [\(self.treeID)] Selecting single SPID \(spid)")
        self.outlineView.selectRowIndexes(indexSet, byExtendingSelection: false)
      }
    }
  }

  /**
   Reloads the row with the given GUID in the NSOutlineView. Convenience function for use by external classes
   */
  func reloadItem(_ guid: GUID, reloadChildren: Bool) {
    // remember, GUID at root of tree is nil
    let effectiveGUID = (guid == self.con.tree.rootSPID.guid) ? nil : guid

    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.treeID)] Reloading item: \(effectiveGUID ?? TOPMOST_GUID) (reloadChildren=\(reloadChildren))")
      self.outlineView.reloadItem(effectiveGUID, reloadChildren: reloadChildren)
    }
  }

  // GAH. Not needed.
  private func removeItem(_ guid: GUID, parentGUID: GUID) {
    // remember, GUID at root of tree is nil
    let effectiveParent = (parentGUID == self.con.tree.rootSPID.guid) ? nil : parentGUID

    DispatchQueue.main.async {
      let indexSet = self.getIndexSetFor(guid)
      if !indexSet.isEmpty {
        NSLog("DEBUG [\(self.treeID)] Removing item: \(guid) with parent: \(effectiveParent ?? TOPMOST_GUID)")
        self.outlineView.removeItems(at: indexSet, inParent: parentGUID, withAnimation: .effectFade)
      }
    }
  }

  // Context Menu
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func initContextMenu() -> NSMenu {
    // The key idea here is that we will use the same menu for all right clicks, but we will rebuild it
    // via the menuNeedsUpdate() method each time it is displayed.
    let rightClickMenu = NSMenu()
    rightClickMenu.delegate = self
    return rightClickMenu
  }

  // This should only be called while the context menu is active
  private func getClickedRowGUID() -> GUID? {
    guard outlineView.clickedRow >= 0 else {
      return nil
    }
    guard let item = outlineView.item(atRow: outlineView.clickedRow) else {
      return nil
    }
    guard let clickedGUID = item as? GUID else {
      return nil
    }

    return clickedGUID
  }

  /**
   Rebuilds the menu each time it's opened, based on the clicked item and/or selection
   */
  func menuWillOpen(_ menu: NSMenu) {
    guard let clickedGUID = self.getClickedRowGUID() else {
      return
    }

    let selectedGUIDs: Set<GUID> = self.getSelectedGUIDs()

    self.con.contextMenu.rebuildMenuFor(menu, clickedGUID, selectedGUIDs)
  }
}
