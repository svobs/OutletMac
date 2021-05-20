//
// Created by Matthew Svoboda on 21/5/17.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import AppKit

/*
 TreeViewController: AppKit controller for TreeViewRepresentable.

 See: https://www.appcoda.com/macos-programming-nsoutlineview/
 See: https://stackoverflow.com/questions/45373039/how-to-program-a-nsoutlineview
 */
final class TreeViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuDelegate {
    // Cannot override init(), but this must be set manually before loadView() is called
    var con: TreePanelControllable! = nil

    let outlineView = NSOutlineView()
    var expandContractListenersEnabled: Bool = true
    var dragOperation: NSDragOperation = .move

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

        let selectedGUIDList = Array(self.getSelectedGUIDs())
        let selectedSNList = displayStore.getSNList(selectedGUIDList)
        self.con.treeActions.confirmAndDeleteSubtrees(selectedSNList)
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

        // Set allowable drag operations:
        outlineView.setDraggingSourceOperationMask([.move, .copy, .delete], forLocal: false)
        // Set allowed pasteboard (drag) types (see NodePasteboardWriter class)
        outlineView.registerForDraggedTypes([.guid])
        outlineView.draggingDestinationFeedbackStyle = .regular
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
     Tell Apple how many children each row has.
    */
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return displayStore.getChildList(itemToGUID(item)).count
    }

    /**
     Tell AppKit whether the row is expandable
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
            // Tell BE to remove the GUID from its persisted state of expanded rows. (No need to make a
            // similar call when the row is expanded; the BE does this automatically when getChildList() called)
            NSLog("DEBUG [\(treeID)] Reporting collapsed node to BE: \(parentGUID)")
            try self.con.backend.removeExpandedRow(parentGUID, self.treeID)
        } catch {
            NSLog("ERROR [\(treeID)] Failed to report collapsed node to BE: \(error)")
        }
    }

    // Drag & Drop
    // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

    /**
     Drag start. Implement this method to allow the table to be an NSDraggingSource that supports multiple item dragging. Return a custom object
     that implements NSPasteboardWriting (or simply use NSPasteboardItem). Return nil to prevent a particular item from being dragged.

     In our case, that means filtering out display-only nodes such as CategoryNodes.
     */
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        let guid: GUID = self.itemToGUID(item)
        if let sn = self.displayStore.getSN(guid) {
            if let node = sn.node {
                if node.isDisplayOnly {
                    NSLog("DEBUG [\(treeID)] Denying drag for node (\(guid)) - it is display only")
                    return nil
                } else {
                    // NSString implements NSPasteboardWriting.
                    return NodePasteboardWriter(guid: guid)
                }
            }
        }

        return nil
    }


    /**
     Implement this method know when the dragging session is about to begin and to potentially modify the dragging session.
     */
//    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
//    }

    /* Dragging Destination Support - Required for multi-image dragging. Implement this method to allow the table to update dragging items as they are dragged over the view. Typically this will involve calling [draggingInfo enumerateDraggingItemsWithOptions:forView:classes:searchOptions:usingBlock:] and setting the draggingItem's imageComponentsProvider to a proper image based on the content. For View Based TableViews, one can use NSTableCellView's -draggingImageComponents and -draggingImageFrame.
     */
//    func outlineView(_ outlineView: NSOutlineView, updateDraggingItemsForDrag draggingInfo: NSDraggingInfo) {
//    }

    /**
     This is implemented to support dropping items onto the Trash icon in the Dock
     */
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard operation == .delete else {
            return
        }

        guard let guidList = TreeViewController.extractGUIDs(session.draggingPasteboard) else {
            return
        }

        NSLog("INFO  [\(treeID)] User dragged to Trash: \(guidList)")
        let snList = displayStore.getSNList(guidList)
        self.con.treeActions.confirmAndDeleteSubtrees(snList)
    }

    private func isDroppingOnSelf(_ srcGUIDList: [GUID], _ dropTargetSN: SPIDNodePair) -> Bool {
        for srcSN in self.displayStore.getSNList(srcGUIDList) {
            // TODO: equals
//            if dropTargetSN.node!.nodeIdentifier == srcSN.node!.nodeIdentifier {
//                NSLog("[\(self.treeID)] DEBUG Target (\(dropTargetSN.spid)) is being dropped on itself")
//                return true
//            }
            if dropTargetSN.node!.isParentOf(srcSN.node!) {
                NSLog("[\(self.treeID)] DEBUG Target dir (\(dropTargetSN.spid)) is parent of dragged node (\(srcSN.spid))")
                return true
            }
        }

        return false
    }

    /**
     Validate Drop

       This method is used by NSOutlineView to determine a valid drop target. Based on the mouse position, the outline view will suggest a proposed child 'index' for the drop to happen as a child of 'item'. This method must return a value that indicates which NSDragOperation the data source will perform. The data source may "re-target" a drop, if desired, by calling setDropItem:dropChildIndex: and returning something other than NSDragOperationNone. One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position). On Leopard linked applications, this method is called only when the drag position changes or the dragOperation changes (ie: a modifier key is pressed). Prior to Leopard, it would be called constantly in a timer, regardless of attribute changes.
     */
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int)
                    -> NSDragOperation {

        if item == nil {
            // Special handling for dropping at the very top: allow the insert bar to be shown
            NSLog("DEBUG [\(treeID)] Validating drop: user is hovering on subtree root")
            // TODO: may want to change 'index' to 'NSOutlineViewDropOnItemIndex' in the future. Not sure which is more intuitive
            outlineView.setDropItem(item, dropChildIndex: index)
            return self.dragOperation
        }

        var dstGUID: GUID = self.itemToGUID(item)

        if index == NSOutlineViewDropOnItemIndex {
            // Possibility I: Dropping ON
            NSLog("DEBUG [\(treeID)] Validating drop: user is hovering on GUID: \(dstGUID)")
        } else {
            // Possibility II: Dropping BETWEEN
            NSLog("DEBUG [\(treeID)] Validating drop: user is hovering at parent GUID: \(dstGUID) child index \(index)")

            // if the drop is between two rows then find the row under the cursor
            if let mouseLocation = NSApp.currentEvent?.locationInWindow {
                let point = outlineView.convert(mouseLocation, from: nil)
                let rowIndex = outlineView.row(at: point)
                if rowIndex >= 0 {
                    if let item = outlineView.item(atRow: rowIndex) {
                        if let guid = item as? GUID {
                            NSLog("DEBUG [\(treeID)] Validating drop: user is hovering over GUID: \(guid)")
                            dstGUID = guid
                        }
                    }
                }
            }
        }

        if var dstSN = displayStore.getSN(dstGUID) {
            if dstSN.node!.isDisplayOnly {
                // cannot drop on non-real nodes such as CategoryNodes. Deny drop
                return []
            }

            if !dstSN.node!.isDir {
                // cannot drop on file. Re-target the drop so that we are dropping on its parent dir
                dstGUID = displayStore.getParentGUID(dstGUID)!
                dstSN = displayStore.getSN(dstGUID)!
            }

            guard let srcGUIDList = TreeViewController.extractGUIDs(info.draggingPasteboard) else {
                return []
            }
            if isDroppingOnSelf(srcGUIDList, dstSN) {
                // Deny drop. Use nice animation to spring back
                return []
            }

            // fall through
        }

        // change the drop item. Always drop onto nodes directly,
        outlineView.setDropItem(dstGUID, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return self.dragOperation
    }

    private func getSrcTreeID(from dragInfo: NSDraggingInfo) -> TreeID? {
        if let dragSource = dragInfo.draggingSource {
            if let srcOutlineView = dragSource as? NSOutlineView {
                if let srcDelegate = srcOutlineView.delegate {
                    if let srcTreeController = srcDelegate as? TreeViewController {
                        return srcTreeController.treeID
                    }
                }
            }
        }
        return nil
    }

    /**
     Accept Drop: executes the drop

     This method is called when the mouse is released over an outline view that previously decided to allow a drop via the validateDrop method.
     The data source should incorporate the data from the dragging pasteboard at this time. 'index' is the location to insert the data as a child of
     'item', and are the values previously set in the validateDrop: method.
     */
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let srcGUIDList = TreeViewController.extractGUIDs(info.draggingPasteboard) else {
            return false
        }

        guard let srcTreeID = self.getSrcTreeID(from: info) else {
            // In the future, we should rework this to support drops from outside the application
            NSLog("ERROR [\(treeID)] Could not get source tree ID from drag source! Aborting drop")
            self.con.reportError("Unexpected Error", "Could not get source tree ID from drag source! Aborting drop")
            return false
        }
        let parentGUID = itemToGUID(item)
        NSLog("DEBUG [\(treeID)] DROPPING \(srcGUIDList) onto parent \(parentGUID) index \(index) from \(srcTreeID)")

        guard let dragTargetSN  = displayStore.getChild(parentGUID, index, useParentIfIndexInvalid: true) else {
            NSLog("DEBUG [\(treeID)] No target found for \(parentGUID)")
            return false
        }
        let dstGUID = dragTargetSN.spid.guid
        NSLog("DEBUG [\(treeID)] DROP onto \(dstGUID)")

        do {
            try self.con.backend.dropDraggedNodes(srcTreeID: srcTreeID, srcGUIDList: srcGUIDList, isInto: true, dstTreeID: treeID, dstGUID: dstGUID)
            return true
        } catch {
            self.con.reportException("Error: Drop Failed!", error)
            return false
        }
    }

    private static func extractGUIDs(_ pasteboard: NSPasteboard) -> [GUID]? {
        guard let pasteboardItems = pasteboard.pasteboardItems else {
            return nil
        }

        // note: type .guid is defined in extension NSPasteboard.PasteboardType
        return pasteboardItems.compactMap{ $0.string(forType: .guid) }
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
        for rowIndex in outlineView.selectedRowIndexes {
            if let item = outlineView.item(atRow: rowIndex) {
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

    private func reloadItem_NoLock(_ guid: GUID, reloadChildren: Bool) {
        // remember, GUID at root of tree is nil
        let effectiveGUID = (guid == self.con.tree.rootSPID.guid) ? nil : guid
        NSLog("DEBUG [\(self.treeID)] Reloading item: \(effectiveGUID ?? TOPMOST_GUID) (reloadChildren=\(reloadChildren))")
        self.outlineView.reloadItem(effectiveGUID, reloadChildren: reloadChildren)
    }

    /**
     Reloads the row with the given GUID in the NSOutlineView. Convenience function for use by external classes
     */
    func reloadItem(_ guid: GUID, reloadChildren: Bool) {
        DispatchQueue.main.async {
            self.reloadItem_NoLock(guid, reloadChildren: reloadChildren)
        }
    }

    func removeItem(_ guid: GUID, parentGUID: GUID) {
        // remember, GUID at root of tree is nil
        let effectiveParent = (parentGUID == self.con.tree.rootSPID.guid) ? nil : parentGUID

        DispatchQueue.main.async {
            let indexInParent = self.outlineView.childIndex(forItem: guid)
            if indexInParent >= 0 {
                var indexSet = IndexSet()
                indexSet.insert(indexInParent)
                NSLog("DEBUG [\(self.treeID)] Removing item: \(guid) with parent: \(effectiveParent ?? TOPMOST_GUID)")
                self.outlineView.removeItems(at: indexSet, inParent: effectiveParent, withAnimation: .effectFade)
            }
            // It seems that the only bug-free way to remove the node is to reload its parent:
//            self.reloadItem_NoLock(parentGUID, reloadChildren: true)
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
