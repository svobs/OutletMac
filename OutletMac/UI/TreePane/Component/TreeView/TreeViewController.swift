//
// Created by Matthew Svoboda on 21/5/17.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import AppKit
import DequeModule

/*
 TreeViewController: AppKit controller for TreeViewRepresentable.

 See: https://www.appcoda.com/macos-programming-nsoutlineview/
 See: https://stackoverflow.com/questions/45373039/how-to-program-a-nsoutlineview
 */
final class TreeViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuDelegate {
    // Cannot override init(), but this must be set manually before loadView() is called
    var con: TreePanelControllable! = nil

    private var guidSelectedSet: Set<GUID> = []

    private let outlineView = NSOutlineView()

    var displayStore: DisplayStore {
        return self.con.displayStore
    }

    var treeID: String {
        return con.treeID
    }

    override func keyDown(with event: NSEvent) {
        NSLog("DEBUG [\(self.treeID)] KEY EVENT: \(event)")
        super.keyDown(with: event)
        // Enable key events
        interpretKeyEvents([event])
        if event.keyCode == 53 {
            NSLog("DEBUG [\(self.treeID)] Escape key pressed!")
            self.con.swiftTreeState.isEditingRoot = false
        }
    }

    /**
     Del key pressed: confirm delete, then delete all selected items
     */
    override func deleteForward(_ sender: Any?) {
        if !self.con.app.globalState.isUIEnabled {
            NSLog("DEBUG [\(treeID)] Ignoring Del key: UI is disabled")
            return
        }
        NSLog("DEBUG [\(self.treeID)] TreeViewController: Del key detected")
        self.deleteSelectedNodes()
    }

    /**
     Delete key pressed: confirm delete, then delete all selected items
     */
    override func deleteBackward(_ sender: Any?) {
        if !self.con.app.globalState.isUIEnabled {
            NSLog("DEBUG [\(treeID)] Ignoring Delete key: UI is disabled")
            return
        }
        NSLog("DEBUG [\(self.treeID)] TreeViewController: Delete key detected")
        self.deleteSelectedNodes()
    }

    private func deleteSelectedNodes() {
        let selectedRowIndexes: IndexSet = outlineView.selectedRowIndexes
        if selectedRowIndexes.isEmpty {
            return
        }

        outlineView.beginUpdates()
        defer {
            outlineView.endUpdates()
        }

        let selectedGUIDList = Array(self.getSelectedGUIDs())
        let selectedNodeList = displayStore.getNodeList(selectedGUIDList)
        self.con.treeActions.confirmAndDeleteSubtrees(selectedNodeList)
    }

    /**
     Double-click handler
     */
    @objc func doubleClickedItem(_ sender: NSOutlineView) {
        if !self.con.app.globalState.isUIEnabled {
            NSLog("DEBUG [\(treeID)] Ignoring double-click: UI is disabled")
            return
        }

        let item = sender.item(atRow: sender.clickedRow)

        let guid = itemToGUID(item)
        let treeAction = TreeAction(self.con.treeID, .BUILTIN(.ACTIVATE), [guid], [])
        do {
            try self.con.backend.executeTreeAction(treeAction)
        } catch {
            self.con.reportException("Failed sending double-click action to backend", error)
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

        outlineView.allowsMultipleSelection = self.con.allowsMultipleSelection

        // Hook up double-click handler
        outlineView.doubleAction = #selector(doubleClickedItem)

        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.menu = self.initContextMenu()

        // Set allowable drag operations:
        outlineView.setDraggingSourceOperationMask([.move, .copy], forLocal: false)
        // Set allowed pasteboard (drag) types (see NodePasteboardWriter class)
        outlineView.registerForDraggedTypes([.guid])
        outlineView.draggingDestinationFeedbackStyle = .regular

        // Set initial sort: this will trigger sortDescriptorsDidChange()
        let sortDescriptor = NSSortDescriptor(key: NAME_COL_KEY, ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)));
        outlineView.sortDescriptors = [sortDescriptor]
        assert (displayStore.getColSortOrder() == .NAME)
    }

    // DataSource methods
    // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

    /**
     Returns a GUID corresponding to the item with the given parameters

     1. You must give each row a unique identifier, referred to as `item` by the outline view.
     2. item == nil means it's the "root" row of the outline view, which is not visible
     */
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let child  = displayStore.getChild(itemToGUID(item), index) {
            return child.spid.guid
        } else {
            NSLog("ERROR [\(treeID)] Could not find item index \(index) of item \(item ?? "nil") in DisplayStore! Returning 'NULL'")
            // hopefully this won't crash!
            return "NULL"
        }
    }

    /**
     Tell Apple how many children each row has.
    */
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return displayStore.getChildGUIDList(itemToGUID(item)).count
    }

    /**
     Tell AppKit whether the row is expandable
     */
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // TODO: in the future, we'll want to download the contents of each child directory so that we
        // can tell whether it is expandable (or at least download a flag saying it has at least 1 child)

        return displayStore.isDir(itemToGUID(item)) && !self.con.swiftFilterState.isFlatList()
    }

    /**
     Callback for updating sort order
     */
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        NSLog("INFO  [\(treeID)] sortDescriptorsDidChange：old=\(oldDescriptors) new=\(self.outlineView.sortDescriptors)")

        let sortDescList = self.outlineView.sortDescriptors
        if sortDescList.count > 0 {
            let primarySort = sortDescList[0]
            if let key = primarySort.key {
                // Don't hang the main thread for what may be a long operation:
                DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                    self.displayStore.updateColSortOrder(key, primarySort.ascending)
                    DispatchQueue.main.async {
                        self.outlineView.reloadData()
                    }
                }
            }
        }
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
            NSLog("ERROR [\(treeID)] viewForTableColumn(): Not a GUID: \(item)")
            return nil
        }

        if guid == self.con.tree.rootSPID.guid {
            NSLog("ERROR [\(treeID)] viewForTableColumn(): Should not be creating a row for the root GUID!")
            return nil
        }

        if TRACE_ENABLED {
            NSLog("DEBUG [\(treeID)] viewForTableColumn(): Cell requested for GUID: \(guid)")
        }

        return CellFactory.upsertCellToOutlineView(self, outlineView, identifier, guid)
    }

    /**
     Filter out rows which should not be selected (e.g., ephemeral nodes).
     From NSOutlineViewDelegate
     Has better performance than shouldSelectItem()
    */
    func outlineView(_ outlineView: NSOutlineView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        var guidList: [GUID] = []
        for index in proposedSelectionIndexes {
            let item = outlineView.item(atRow: index)
            if let guid = item as? GUID {
                guidList.append(guid)
            } else {
                NSLog("ERROR [\(treeID)] selectionIndexesForProposedSelection(): not a GUID: \(item ?? "nil")")
            }
        }
        let filteredSet: Set<GUID> = self.displayStore.toFilteredSet(guidList)
        return self.getIndexSetFor(filteredSet)
    }

    /**
     Post Selection Change
     From NSOutlineViewDelegate
    */
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let guidSet: Set<GUID> = self.getSelectedGUIDs()
        NSLog("DEBUG [\(treeID)] User selected GUIDs: \(guidSet)")
        self.guidSelectedSet = guidSet

        do {
            try self.con.backend.setSelectedRowSet(guidSet, self.treeID)
        } catch {
            // Not a serious error: don't show to user
            NSLog("Failed to report node selection: \(error)")
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
        guard self.con.expandContractListenersEnabled else {
            return
        }

        guard let parentGUID: GUID = getGUID(notification) else {
            NSLog("ERROR [\(treeID)] Cannot expand topmost GUID (nil)! Ignoring request")
            return
        }

        guard parentGUID != self.con.tree.rootSPID.guid else {
            NSLog("ERROR [\(treeID)] Cannot expand topmost GUID ('\(parentGUID)')! Ignoring request")
            return
        }

        guard let parentSN: SPIDNodePair = self.displayStore.getSN(parentGUID) else {
            NSLog("ERROR [\(treeID)] Cannot expand: GUID '\(parentGUID)' not found in DisplayStore. Ignoring request")
            return
        }

        NSLog("DEBUG [\(treeID)] Row is expanding: \(parentGUID)")

        do {
            let childSNList = try self.con.backend.getChildList(parentSPID: parentSN.spid, treeID: self.treeID, isExpandingParent: true,
                    maxResults: MAX_NUMBER_DISPLAYABLE_CHILD_NODES)

            outlineView.beginUpdates()
            defer {
                outlineView.endUpdates()
            }
            self.displayStore.putChildList(parentSN.spid.guid, childSNList)
            self.outlineView.reloadItem(parentGUID, reloadChildren: true)
        } catch OutletError.maxResultsExceeded(let actualCount) {
            DispatchQueue.main.async {
                self.con.appendEphemeralNode(parentSN.spid, "ERROR: too many items to display (\(actualCount))", .ICON_ALERT, reloadParent: true)
            }
        } catch {
            self.con.reportException("Failed to expand row", error)
        }
    }

    /**
     Pre Row Collapse
     From NSOutlineViewDelegate

     IMPORTANT NOTE: MacOS has its own quirk when collapsing a node which has expanded descendants. By default, collapsing it will "secretly" keep
     the state of its expanded descendants, so that expanding it again right away will restore their expanded states as well. The user can override
     this behavior by holding down the Option key when collapsing the node, which in effect will collapse all the descendants.
     Reference: https://developer.apple.com/documentation/appkit/nsoutlineview/1531436-collapseitem

     Currently the BE will honor this behavior while the app is open (because the descendant states are remembered by the NSOutlineView), but if the
     app is closed, on the next run any descendants which were collapsed at the end of the last run will stay that way.
     */
    func outlineViewItemWillCollapse(_ notification: Notification) {
        guard let parentGUID: GUID = getGUID(notification) else {
            return
        }
        guard parentGUID != self.con.tree.rootSPID.guid else {
            NSLog("ERROR [\(treeID)] Trying to collapse topmost GUID (\(parentGUID)); ignoring")
            return
        }
        NSLog("DEBUG [\(treeID)] Row is collapsing: \(parentGUID)")

        displayStore.removeDescendants(parentGUID)

        do {
            // Tell BE to remove the GUID from its persisted state of expanded rows. (No need to make a
            // similar call when the row is expanded; the BE does this automatically when getChildList() called)
            NSLog("DEBUG [\(treeID)] Reporting collapsed row to BE: \(parentGUID)")
            try self.con.backend.removeExpandedRow(parentGUID, self.treeID)
        } catch {
            NSLog("ERROR [\(treeID)] Failed to report collapsed row to BE: \(error)")
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
        if !self.con.app.globalState.isUIEnabled {
            NSLog("DEBUG [\(treeID)] Denying drag: UI is disabled")
            return nil
        }
        // FIXME: handle drag for all types of trees (e.g. MergePreviewTree)
        let guid: GUID = self.itemToGUID(item)
        if let sn = self.displayStore.getSN(guid) {
            if sn.node.isDisplayOnly {
                NSLog("DEBUG [\(treeID)] Denying drag for node (\(guid)) - it is display only")
                return nil
            } else {
                let fileURL = sn.spid.treeType == .LOCAL_DISK ? sn.spid.getSinglePath() : nil
                return NodePasteboardWriter(guid: guid, fileURL: fileURL)
            }
        }

        return nil
    }

    /**
     This is implemented to support dropping items onto the Trash icon in the Dock
     */
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard operation == NSDragOperation.delete else {
            return
        }

        if !self.con.app.globalState.isUIEnabled {
            NSLog("DEBUG [\(treeID)] Denying drop to trash: UI is disabled")
            return
        }

        guard let guidList = TreeViewController.extractGUIDs(session.draggingPasteboard) else {
            return
        }

        NSLog("INFO  [\(treeID)] User dragged to Trash: \(guidList)")
        let nodeList = displayStore.getNodeList(guidList)
        self.con.treeActions.confirmAndDeleteSubtrees(nodeList)
    }

    /**
     Validate Drop

       This method is used by NSOutlineView to determine a valid drop target. Based on the mouse position, the outline view will suggest a proposed child 'index' for the drop to happen as a child of 'item'. This method must return a value that indicates which NSDragOperation the data source will perform. The data source may "re-target" a drop, if desired, by calling setDropItem:dropChildIndex: and returning something other than NSDragOperationNone. One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position). On Leopard linked applications, this method is called only when the drag position changes or the dragOperation changes (ie: a modifier key is pressed). Prior to Leopard, it would be called constantly in a timer, regardless of attribute changes.
     */
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int)
                    -> NSDragOperation {

        if !self.con.app.globalState.isUIEnabled {
            NSLog("DEBUG [\(treeID)] Denying drop: UI is disabled")
            return []
        }

        let dragOperation = self.getDragOperation(info).getNSDragOperation()

        if item == nil {
            // Special handling for dropping at the very top: allow the insert bar to be shown
            if SUPER_DEBUG_ENABLED {
                NSLog("DEBUG [\(treeID)] Validating drop: user is hovering on subtree root")
            }
            // TODO: may want to change 'index' to 'NSOutlineViewDropOnItemIndex' in the future. Not sure which is more intuitive
            outlineView.setDropItem(item, dropChildIndex: index)
            return dragOperation
        }

        var dstGUID: GUID = self.itemToGUID(item)

        if index == NSOutlineViewDropOnItemIndex {
            // Possibility I: Dropping ON
            if SUPER_DEBUG_ENABLED {
                NSLog("DEBUG [\(treeID)] Validating drop: user is hovering on GUID: \(dstGUID)")
            }
        } else {
            // Possibility II: Dropping BETWEEN
            if SUPER_DEBUG_ENABLED {
                NSLog("DEBUG [\(treeID)] Validating drop: user is hovering at parent GUID: \(dstGUID) child index \(index)")
            }

            // if the drop is between two rows then find the row under the cursor
            if let mouseLocation = NSApp.currentEvent?.locationInWindow {
                let point = outlineView.convert(mouseLocation, from: nil)
                let rowIndex = outlineView.row(at: point)
                if rowIndex >= 0 {
                    if let item = outlineView.item(atRow: rowIndex) {
                        dstGUID = itemToGUID(item)
                        if SUPER_DEBUG_ENABLED {
                            NSLog("DEBUG [\(treeID)] Validating drop: user is hovering over GUID: \(dstGUID)")
                        }
                    }
                }
            }
        }

        if var dstSN = displayStore.getSN(dstGUID) {
            if dstSN.node.isDisplayOnly {
                // cannot drop on non-real nodes such as CategoryNodes. Deny drop
                return []
            }

            if !dstSN.node.isDir {
                // cannot drop on file. Re-target the drop so that we are dropping on its parent dir
                guard let parentGUID = displayStore.getParentGUID(dstGUID) else {
                    return []
                }
                guard let parentSN = displayStore.getSN(parentGUID) else {
                    return []
                }
                dstGUID = parentGUID
                dstSN = parentSN
            }

            guard let srcGUIDList = TreeViewController.extractGUIDs(info.draggingPasteboard) else {
                if SUPER_DEBUG_ENABLED {
                    NSLog("DEBUG [\(treeID)] Validating drop: no src GUIDs found")
                }
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
        return dragOperation
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
        let dragOperation = self.getDragOperation(info)
        let dirConflictPolicy = self.con.app.globalState.currentDirConflictPolicy
        let fileConflictPolicy = self.con.app.globalState.currentFileConflictPolicy

        NSLog("DEBUG [\(treeID)] DROP onto \(dstGUID) (DragOp=\(dragOperation) DirPolicy=\(dirConflictPolicy) FilePolicy=\(fileConflictPolicy))")

        do {
            return try self.con.backend.dropDraggedNodes(srcTreeID: srcTreeID, srcGUIDList: srcGUIDList, isInto: true,
                    dstTreeID: treeID, dstGUID: dstGUID, dragOperation: dragOperation, dirConflictPolicy: dirConflictPolicy, fileConflictPolicy: fileConflictPolicy)
        } catch {
            self.con.reportException("Error: Drop Failed!", error)
            return false
        }
    }

    private func isDroppingOnSelf(_ srcGUIDList: [GUID], _ dropTargetSN: SPIDNodePair) -> Bool {
        if SUPER_DEBUG_ENABLED {
            NSLog("DEBUG [\(self.treeID)] isDroppingOnSelf: checking srcList (\(srcGUIDList)) against drop target (\(dropTargetSN.spid))")
        }
        // It's ok if some of these don't resolve. We'll do more complex validation on the backend.
        for srcSN in self.displayStore.getSNList(srcGUIDList) {
            if dropTargetSN.node.isParentOf(srcSN.node) {
                if SUPER_DEBUG_ENABLED {  // // this can get called a lot when user is hovering
                    NSLog("DEBUG [\(self.treeID)] Drop target dir (\(dropTargetSN.spid)) is already parent of dragged node (\(srcSN.spid))")
                }
                return true
            }
        }

        return false
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
     If the dragOperation == .every, then it indicates the default drag operation. Otherwise it can be one of the allowed options
     which the user may have activated (e.g., holding down the Option key changes to a COPY).
     See: https://stackoverflow.com/questions/32408338/how-can-i-allow-moving-and-copying-by-dragging-rows-in-an-nstableview
     */
    private func getDragOperation(_ info: NSDraggingInfo) -> DragOperation {
        let currentDefaultOperation = self.con.app.globalState.getCurrentDefaultDragOperation()
        let dragOperation: NSDragOperation = info.draggingSourceOperationMask

        let currentDefault = currentDefaultOperation.getNSDragOperation().rawValue

        let dragMask = dragOperation.rawValue == NSDragOperation.every.rawValue ? currentDefault : dragOperation.rawValue
        switch dragMask {
        case NSDragOperation.copy.rawValue:
            // Option key held down:
            return .COPY
        case NSDragOperation.move.rawValue:
            // Command key held down:
            return .MOVE
        case NSDragOperation.link.rawValue:
            // Control key held down:
            return .LINK
        case NSDragOperation.delete.rawValue:
            // When is this activated?
            return .DELETE
        default:
            NSLog("WARN  [\(self.treeID)] Unrecognized drag operation: \(dragOperation.rawValue) (will return current default: \(currentDefault)")
            return currentDefaultOperation
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
            return self.con.tree.rootSPID.guid
        } else {
            return item as! GUID
        }
    }

    private func guidToItem(_ guid: GUID) -> Any? {
        if guid == self.con.tree.rootSPID.guid {
            return nil
        } else {
            return guid
        }
    }

    func getSelectedUIDs() -> Set<UID> {
        var uidSet = Set<UID>()
        for rowIndex in outlineView.selectedRowIndexes {
            if let item = outlineView.item(atRow: rowIndex) {
                if let sn = displayStore.getSN(itemToGUID(item)) {
                    uidSet.insert(sn.node.uid)
                }
            }
        }
        return uidSet
    }

    /**
     Note: currently this will include any selected ephemeral nodes. It's currently not worth the cycles
     to weed them out (we are not currently doing any lookups in the DisplayStore)
     */
    func getSelectedGUIDs() -> Set<GUID> {
        var guidSet = Set<GUID>()
        for selectedRow in outlineView.selectedRowIndexes {
            if let item = outlineView.item(atRow: selectedRow) {
                guidSet.insert(itemToGUID(item))
            }
        }
        return guidSet
    }

    /**
     Gets the GUID (if any) from the given Notification, and returns it.
     */
    private func getGUID(_ notification: Notification) -> GUID? {
        guard let item = notification.userInfo?["NSObject"] else {
            NSLog("ERROR [\(treeID)] getGUID(): no item")
            return nil
        }

        return itemToGUID(item)
    }

    /**
     NOTE: this MUST be called on the main thread!
     */
    func getIndexSetFor(_ guidSet: Set<GUID>) -> IndexSet {
        var indexSet = IndexSet()
        for guid in guidSet {
            // Item will never be nil because we cannot get row for root. However, row may not be present
            let index = self.outlineView.row(forItem: guid)
            if index < 0 {
                NSLog("WARN  [\(self.treeID)] Index not found for GUID, omitting: \(guid)")
            } else {
                indexSet.insert(index)
            }
        }

        return indexSet
    }

    /**
     Selects the row with the given GUID in the tree UI, if it exists
     */
    func selectSingleGUID(_ guid: GUID) {
        assert(DispatchQueue.isExecutingIn(.main))

        let indexSet = self.getIndexSetFor([guid])
        if !indexSet.isEmpty {
            NSLog("DEBUG [\(self.treeID)] Selecting single GUID \(guid)")
            self.outlineView.selectRowIndexes(indexSet, byExtendingSelection: false)
        }
    }

    func selectGUIDList(_ guidSet: Set<GUID>) {
        assert(DispatchQueue.isExecutingIn(.main))

        self.guidSelectedSet = guidSet

        if guidSet.count == 0 {
            return
        }

        NSLog("DEBUG [\(self.treeID)] Selecting GUIDs: \(guidSet)")
        let indexSet = self.getIndexSetFor(guidSet)
        NSLog("DEBUG [\(self.treeID)] selectGUIDList(): resolved \(guidSet.count) GUIDs into \(indexSet.count) rows")

        if !indexSet.isEmpty {
            if SUPER_DEBUG_ENABLED {
                NSLog("DEBUG [\(self.treeID)] selectGUIDList(): selecting \(indexSet.count) rows: \(guidSet)")
            } else {
                NSLog("DEBUG [\(self.treeID)] selectGUIDList(): selecting \(indexSet.count) rows")
            }

            self.outlineView.selectRowIndexes(indexSet, byExtendingSelection: false)
        }
    }

    /**
     Reloads the row with the given GUID in the NSOutlineView. Convenience function for use by external classes
     */
    func reloadItem(_ guid: GUID, reloadChildren: Bool) {
        DispatchQueue.main.async {
            // turn off listeners so that we do not trigger gRPC getChildList() for expanded nodes:
            self.con.expandContractListenersEnabled = false
            defer {
                self.con.expandContractListenersEnabled = true
            }
            // remember, GUID at root of tree is nil
            let item = self.guidToItem(guid)
            NSLog("DEBUG [\(self.treeID)] Reloading item: \(item ?? "<root>") (reloadChildren=\(reloadChildren))")
            self.outlineView.reloadItem(item, reloadChildren: reloadChildren)
        }
    }

    /**
     If isAlreadyPopulated==true, do not use the animator to expand the nodes, and disable the listeners so that network calls are not made to
     populate the DisplayStore.
     */
    func expand(_ toExpandInOrder: [GUID], isAlreadyPopulated: Bool) {
        assert(DispatchQueue.isExecutingIn(.main))

        self.outlineView.beginUpdates()
        if isAlreadyPopulated {
            // disable listeners while we restore expansion state
            self.con.expandContractListenersEnabled = false
        }
        defer {
            if isAlreadyPopulated {
                self.con.expandContractListenersEnabled = true
            }
            self.outlineView.endUpdates()
        }

        NSLog("DEBUG [\(self.treeID)] Expanding rows: \(toExpandInOrder)")
        for guid in toExpandInOrder {
            NSLog("DEBUG [\(self.treeID)] Expanding item: \"\(guid)\"")
            if isAlreadyPopulated {
                self.outlineView.expandItem(guid)
            } else {
                outlineView.animator().expandItem(guid)
            }
        }
    }

    /**
     Expands all of the rows with the given GUIDs, and also all of their descendants, using an animation.
     */
    func expandAll(_ guidList: [GUID]) {
        assert(DispatchQueue.isExecutingIn(.main))

        let snList = self.con.displayStore.getSNList(guidList)
        guard snList.count > 0 else {
            return
        }

        self.outlineView.beginUpdates()
        defer {
            self.outlineView.endUpdates()
        }

        // contains items which were just expanded and need their children examined
        var queue = Deque<SPIDNodePair>()

        func process(_ sn: SPIDNodePair) {
            if sn.node.isDir {
                let guid = sn.spid.guid
                if !outlineView.isItemExpanded(guid) {
                    NSLog("DEBUG [\(self.treeID)] Expanding item: \"\(guid)\"")
                    outlineView.animator().expandItem(guid)
                }
                queue.append(sn)
            }
        }

        for sn in snList {
            process(sn)
        }

        while !queue.isEmpty {
            let parentSN = queue.popFirst()!
            let parentGUID = parentSN.spid.guid
            for sn in self.con.displayStore.getChildSNList(parentGUID) {
                process(sn)
            }
        }
    }

    func collapse(_ guidList: [GUID]) {
        assert(DispatchQueue.isExecutingIn(.main))

        self.outlineView.beginUpdates()
        defer {
            self.outlineView.endUpdates()
        }
        for guid in guidList {
            outlineView.animator().collapseItem(guid, collapseChildren: true)
        }
    }

    func reloadData() {
        assert(DispatchQueue.isExecutingIn(.main))

        NSLog("DEBUG [\(self.treeID)] Reloading TreeView from DisplayStore")
        self.outlineView.reloadData()
        // The previous line can wipe out our selection. Try to restore it:
        self.selectGUIDList(self.guidSelectedSet)
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

    /**
     This should only be called while the context menu is active
     */
    private func getClickedRowGUID() -> GUID? {
        guard outlineView.clickedRow >= 0 else {
            return nil
        }
        guard let item = outlineView.item(atRow: outlineView.clickedRow) else {
            return nil
        }

        return itemToGUID(item)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if !self.con.app.globalState.isUIEnabled {
            NSLog("DEBUG [\(treeID)] menuNeedsUpdate(): UI is disabled")
            //This will prevent menu from showing
            menu.removeAllItems()
            return
        }

        NSLog("DEBUG [\(treeID)] menuNeedsUpdate() entered")

        guard let clickedGUID = self.getClickedRowGUID() else {
            return
        }

        let selectedGUIDs: Set<GUID> = self.getSelectedGUIDs()

        self.con.contextMenu.rebuildMenuFor(menu, clickedGUID, selectedGUIDs)
    }

}
