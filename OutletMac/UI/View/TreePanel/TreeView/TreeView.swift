import Cocoa
import AppKit
import SwiftUI
import Foundation
import LinkedList

/**
 TreeView: extra layer of TreeView to specify layout
 */
struct TreeView: View {
  let con: TreeControllable
  @EnvironmentObject var settings: GlobalSettings
  @ObservedObject var heightTracking: HeightTracking

  init(controller: TreeControllable, _ heightTracking: HeightTracking) {
    self.con = controller
    self.heightTracking = heightTracking
  }

  var body: some View {
    HStack {
      TreeViewRepresentable(controller: self.con)
        .padding(.top)
        .frame(minWidth: 200,
               maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               // A redraw of this view should be triggered when either of these values are changed:
               minHeight: heightTracking.getTreeViewHeight(),
               maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               alignment: .topLeading)
    }
    .frame(alignment: .topLeading)
  }
}

/**
 TreeViewRepresentable: SwiftUI wrapper for NSOutlineView
 */
struct TreeViewRepresentable: NSViewControllerRepresentable {
  let con: TreeControllable

  init(controller: TreeControllable) {
    self.con = controller
  }

  func makeNSViewController(context: Context) -> TreeViewController {
    // TOOD: find better names for TreeController/TreeControllable

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
  private var _lazyCon: TreeControllable? = nil
  var con: TreeControllable {
    get {
      return _lazyCon!
    }
    set (con) {
      self._lazyCon = con
    }
  }

  private let treeController = NSTreeController()
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

  private func configureOutlineView(_ scrollView: NSScrollView) {
    outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
    outlineView.allowsMultipleSelection = true
    outlineView.autosaveTableColumns = true
    outlineView.autosaveExpandedItems = true
    outlineView.rowSizeStyle = .large
    outlineView.lineBreakMode = .byTruncatingTail
    outlineView.cell?.truncatesLastVisibleLine = true
    outlineView.autoresizesOutlineColumn = true
    outlineView.indentationPerLevel = 16
//    outlineView.backgroundColor = .clear
    outlineView.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)

    outlineView.headerView = NSTableHeaderView()

    // Columns:

    let nodeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
    nodeColumn.title = "Name"
    nodeColumn.width = 300
    nodeColumn.minWidth = 150
    nodeColumn.isEditable = false
    outlineView.addTableColumn(nodeColumn)

    let sizeBytesCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "size"))
    sizeBytesCol.title = "Size"
    sizeBytesCol.width = 70
    sizeBytesCol.minWidth = 70
    sizeBytesCol.isEditable = false
    outlineView.addTableColumn(sizeBytesCol)

    let etcCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "etc"))
    etcCol.title = "Etc"
    etcCol.width = 200
    etcCol.minWidth = 100
    etcCol.isEditable = false
    outlineView.addTableColumn(etcCol)

    let mtimeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "mtime"))
    mtimeCol.title = "Modification Time"
    mtimeCol.width = 200
    mtimeCol.minWidth = 100
    mtimeCol.isEditable = false
    outlineView.addTableColumn(mtimeCol)

    let ctimeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "ctime"))
    ctimeCol.title = "Meta Change Time"
    ctimeCol.width = 200
    ctimeCol.minWidth = 100
    ctimeCol.isEditable = false
//    ctimeCol.isHidden = true
    outlineView.addTableColumn(ctimeCol)

//    outlineView.backgroundColor = .clear
//    outlineView.usesAlternatingRowBackgroundColors = true // TODO: the colors are screwed up when this is used
//    outlineView.gridStyleMask = .dashedHorizontalGridLineMask
//    outlineView.selectionHighlightStyle = .sourceList // selection highlight has rounded corners (TODO: this introduces ugly extra space)
    outlineView.autosaveExpandedItems = true
    outlineView.usesAutomaticRowHeights = true  // set row height to match font

    scrollView.documentView = outlineView
    outlineView.frame = scrollView.bounds
    outlineView.delegate = self
    outlineView.dataSource = self

    // Hook up double-click handler
    outlineView.doubleAction = #selector(doubleClickedItem)

    outlineView.menu = self.initContextMenu()
  }

  private func addScrollView() -> NSScrollView {
    let scrollView = NSScrollView()

    scrollView.backgroundColor = NSColor.clear
    scrollView.drawsBackground = false
    scrollView.hasHorizontalScroller = true
    scrollView.hasVerticalScroller = true
    scrollView.horizontalPageScroll = 10
    scrollView.verticalLineScroll = 19
    scrollView.verticalPageScroll = 10
    scrollView.automaticallyAdjustsContentInsets = true

    self.view.addSubview(scrollView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0))
    self.view.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0))
    self.view.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 0))
    self.view.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: 0))

    return scrollView
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // ScrollView
    let scrollView = self.addScrollView()

    // OutlineView
    self.configureOutlineView(scrollView)
  }

  // DataSource methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func itemToGUID(_ item: Any?) -> GUID {
    if item == nil {
      return NULL_GUID
    } else {
      return item as! GUID
    }
  }

  /**
   Returns a GUID corresponding to the item with the given parameters

   1. You must give each row a unique identifier, referred to as `item` by the outline view.
   2. For top-level rows, we use the values in the `keys` array
   3. item == nil means it's the "root" row of the outline view, which is not visible
   */
  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if let child  = displayStore.getChild(itemToGUID(item), index) {
      return displayStore.guidFor(child)
    } else {
      return NULL_GUID
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
    return displayStore.isDir(itemToGUID(item))
  }

  /**
   Thanks to "jnpdx" from here for this:
   https://stackoverflow.com/questions/66165528/how-to-change-nstextfield-font-size-when-used-in-swiftui
   */
  private class CustomFontNSTextField : NSTextField {
    func customSetFont(_ font: NSFont?) {
      super.font = font
    }

    /**
     There seems to be a bug in Apple's code in Big Sur which causes font to be continuously set to system font, size 18.
     Override this to prevent this from happening.
     */
    override var font: NSFont? {
      get {
        return super.font
      }
      set {}
    }
  }

  private func makeIcon(_ sn: SPIDNodePair, _ cell: NSTableCellView) -> NSImage? {
    guard let node = sn.node else {
      return nil
    }

    // At this point, the text field should know its desired height, which will also (eventually) be the height of the cell
    let cellHeight = cell.textField!.bounds.height
//    NSLog("CELL HEIGHT: \(cellHeight)")

    var icon: NSImage
    if node.isDir {
      icon = NSWorkspace.shared.icon(for: .folder)
    } else if node.isEphemeral {
      // TODO: warning icon
      icon = NSWorkspace.shared.icon(for: .application)
    } else {
      let suffix = URL(fileURLWithPath: node.firstPath).pathExtension
      if suffix == "" {
        icon = NSWorkspace.shared.icon(for: .data)
      } else {
        icon = NSWorkspace.shared.icon(forFileType: suffix)
      }
    }

    // Thanks to "Sweeper" at https://stackoverflow.com/questions/62525921/how-to-get-a-high-resolution-app-icon-for-any-application-on-a-mac
    if let imageRep = icon.bestRepresentation(for: NSRect(x: 0, y: 0, width: cellHeight, height: cellHeight), context: nil, hints: nil) {
      icon = NSImage(size: imageRep.size)
      icon.addRepresentation(imageRep)
    }

    icon.size = NSSize(width: cellHeight, height: cellHeight)

    return icon
  }

  private func makeCellWithTextAndIcon(for sn: SPIDNodePair, withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {

    let cell = self.makeCellWithText(withIdentifier: identifier)

    // FIXME: need to figure out how to align icon and text properly AND also make it compact

    guard let icon = self.makeIcon(sn, cell) else {
      return cell
    }
    let imageView = NSImageView(image: icon)
    imageView.imageAlignment = .alignCenter  // FIXME: this is not right
    imageView.imageFrameStyle = .none
    cell.addSubview(imageView)
    cell.imageView = imageView

    imageView.heightAnchor.constraint(lessThanOrEqualTo: cell.heightAnchor).isActive = true
    cell.imageView!.centerYAnchor.constraint(equalTo: cell.textField!.centerYAnchor).isActive = true

    // Make sure the text is placed to the right of the icon:
    cell.textField!.leftAnchor.constraint(equalTo: imageView.rightAnchor).isActive = true

    cell.imageView!.sizeToFit()
    cell.needsLayout = true

    return cell
  }

  private func makeCellWithText(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
    let cell = NSTableCellView()
    cell.identifier = identifier

    let textField = CustomFontNSTextField()
    textField.backgroundColor = NSColor.clear
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.isBordered = false
    textField.isBezeled = false
    textField.isEditable = false
    textField.customSetFont(TREE_VIEW_NSFONT)
    textField.lineBreakMode = .byTruncatingTail
    cell.addSubview(textField)
    cell.textField = textField

    // Constrain the text field within the cell
    textField.heightAnchor.constraint(lessThanOrEqualTo: cell.heightAnchor).isActive = true
    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
    textField.sizeToFit()
//    textField.setFrameOrigin(NSZeroPoint)

    return cell
  }

  // NSOutlineViewDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Makes contents of the cell
   From NSOutlineViewDelegate
   */
  public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let identifier = tableColumn?.identifier else { return nil }

    guard let guid = item as? GUID else {
      NSLog("ERROR [\(treeID)] viewForTableColumn(): not a GUID: \(item)")
      return nil
    }

    guard let sn = self.displayStore.getSN(guid) else {
      NSLog("ERROR [\(treeID)] viewForTableColumn(): node not found with GUID: \(guid)")
      return nil
    }

    let node = sn.node!
    switch identifier.rawValue {
      case "name":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCellWithTextAndIcon(for: sn, withIdentifier: identifier)
        }
        cell!.imageView!.image = self.makeIcon(sn, cell!)
        cell!.textField!.stringValue = node.name
        return cell
      case "size":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCellWithText(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = StringUtil.formatByteCount(node.sizeBytes)
        return cell
      case "etc":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCellWithText(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = String(node.etc)
        return cell
      case "mtime":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCellWithText(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = DateUtil.formatTS(node.modifyTS)
        return cell
      case "ctime":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCellWithText(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = DateUtil.formatTS(node.changeTS)
        return cell
      default:
        NSLog("ERROR [\(treeID)] unrecognized identifier (ignoring): \(identifier.rawValue)")
        return nil
    }
  }

  /**
   SELECTION CHANGED
  */
  func outlineViewSelectionDidChange(_ notification: Notification) {
    let uidSet: Set<UID> = self.getSelectedUIDs()
    NSLog("DEBUG [\(treeID)] User selected UIDs: \(uidSet)")

    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        try self.con.backend.setSelectedRowSet(uidSet, self.treeID)
      } catch {
        // Not a serious error: don't show to user
        NSLog("Failed to report node selection: \(error)")
      }
    }
  }

  func getSelectedUIDs() -> Set<UID> {
    var uidSet = Set<UID>()
    for selectedRow in outlineView.selectedRowIndexes {
      if let item = outlineView.item(atRow: selectedRow) {
        if let guid = item as? GUID {
          if let sn = displayStore.getSN(guid) {
            uidSet.insert(sn.spid.uid)
          }
        }
      }
    }
    return uidSet
  }

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

  /**
   EXPAND ROW
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

    let parentUID: UID = parentSN.spid.uid

    NSLog("DEBUG [\(treeID)] User expanded node \(parentGUID)")

    do {
      let childNodeList = try self.con.backend.getChildList(parentUID: parentUID, treeID: self.treeID, maxResults: MAX_NUMBER_DISPLAYABLE_CHILD_NODES)

      outlineView.beginUpdates()
      defer {
        outlineView.endUpdates()
      }
      let childSNList: [SPIDNodePair] = self.displayStore.convertChildList(parentSN, childNodeList)
      self.displayStore.populateChildList(parentSN, childSNList)
      self.outlineView.reloadItem(parentGUID, reloadChildren: true)
//      self.outlineView.insertItems(at: IndexSet(0...0), inParent: parent, withAnimation: .effectFade)
    } catch OutletError.maxResultsExceeded(let actualCount) {
      self.con.appendEphemeralNode(parentSN, "ERROR: too many items to display (\(actualCount))")
    } catch {
      self.con.reportException("Failed to expand node", error)
    }
  }

  /**
   COLLAPSE ROW
  */
  func outlineViewItemWillCollapse(_ notification: Notification) {
    guard let parentGUID: GUID = getKey(notification) else {
      return
    }
    NSLog("DEBUG [\(treeID)] User collapsed node \(parentGUID)")
    guard let parentSN: SPIDNodePair = self.displayStore.getSN(parentGUID) else {
      return
    }

    /*
     FIXME: we have a broken model here. The BE stores expanded/collapsed UIDs, but we need it to store GUIDs.
     Continuing to use UIDs will result in GDrive nodes being incorrectly expanded if they are linked more than
     once in the same UI tree.
     However, the BE currently has no idea what a GUID is.
     This is expected to be a minor issue but let's fix it in the future by adding BE support.
    */

    /*
     FIXME: need to remove all children from the list of epxanded rows. Otherwise we'll end up restoring the expanded
     state of any nested directories when we expand again. Some may consider this a feature
    */

    do {
      try self.con.backend.removeExpandedRow(parentSN.spid.uid, self.treeID)
    } catch {
      NSLog("ERROR [\(treeID)] Failed to report collapsed node to BE: \(error)")
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
