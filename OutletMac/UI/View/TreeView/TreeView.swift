import Cocoa
import AppKit
import SwiftUI
import Foundation

/**
 TreeView: SwiftUI wrapper for TreeView
 */
struct TreeView: NSViewControllerRepresentable {
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
final class TreeViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
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

  // Delete row if Delete key pressed:
  override func deleteBackward(_ sender: Any?) {

    let selectedRowIndexes: IndexSet = outlineView.selectedRowIndexes
    if selectedRowIndexes.isEmpty {
      return
    }

    outlineView.beginUpdates()
    defer {
      outlineView.endUpdates()
    }

    for selectedRow in selectedRowIndexes {
      if let item = outlineView.item(atRow: selectedRow) {
        if let uid = item as? UID {
          // TODO: hook this up to backend
        }
      }
    }
    outlineView.removeItems(at: selectedRowIndexes, inParent: nil, withAnimation: .slideLeft)

    // TODO: see also: moveItemAtIndex(_:, inParent:, toIndex:, inParent:)


  }

  // TODO: how to hook this up?
  func doubleClickedItem(_ sender: NSOutlineView) {
    let item = sender.item(atRow: sender.clickedRow)

    if item is UID {
      if sender.isItemExpanded(item) {
        sender.collapseItem(item)
      } else {
        sender.expandItem(item)
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
    outlineView.indentationPerLevel = 16
    outlineView.backgroundColor = .clear
    outlineView.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)

    outlineView.headerView = NSTableHeaderView()

    // Columns:

    let nodeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
    nodeColumn.title = "Name"
    nodeColumn.width = 300
    nodeColumn.minWidth = 100
    nodeColumn.isEditable = false
    outlineView.addTableColumn(nodeColumn)

    let sizeBytesCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "size"))
    sizeBytesCol.title = "Size"
    sizeBytesCol.width = 100
    sizeBytesCol.minWidth = 100
    sizeBytesCol.isEditable = false
    outlineView.addTableColumn(sizeBytesCol)

    let etcCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "etc"))
    etcCol.title = "Etc"
    etcCol.width = 100
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

    outlineView.gridStyleMask = .solidHorizontalGridLineMask
    outlineView.autosaveExpandedItems = true

    scrollView.documentView = outlineView
    outlineView.frame = scrollView.bounds
    outlineView.delegate = self
    outlineView.dataSource = self
  }

  private func addScrollView() -> NSScrollView {
    let scrollView = NSScrollView()

    scrollView.backgroundColor = NSColor.clear
    scrollView.drawsBackground = false
    scrollView.hasHorizontalScroller = false
    scrollView.hasVerticalScroller = true
    scrollView.horizontalPageScroll = 10
    scrollView.verticalLineScroll = 19
    scrollView.verticalPageScroll = 10

    self.view.addSubview(scrollView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0))
    self.view.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 23))
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

  private func itemToUID(_ item: Any?) -> UID {
    if item == nil {
      return NULL_UID
    } else {
      return item as! UID
    }
  }

  /**
   Returns a UID corresponding to the item with the given parameters

   1. You must give each row a unique identifier, referred to as `item` by the outline view.
   2. For top-level rows, we use the values in the `keys` array
   3. item == nil means it's the "root" row of the outline view, which is not visible
   */
  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    return displayStore.getChild(itemToUID(item), index)?.uid ?? NULL_UID
  }

  /**
  // Tell Apple how many children each row has.
  */
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    return displayStore.getChildList(itemToUID(item)).count
  }

  /**
   Tell whether the row is expandable
   */
  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    return displayStore.getNode(itemToUID(item))?.isDir ?? false
  }



  private func makeCell(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
    let textField = NSTextField()
    textField.backgroundColor = NSColor.clear
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.isBordered = false
    textField.isEditable = false
    // FIXME: this doesn't work
    textField.font = NSFont.systemFont(ofSize: 7)

    let cell = NSTableCellView()
    cell.identifier = identifier
    cell.addSubview(textField)
    cell.textField = textField

    // Constrain the text field within the cell
    textField.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true
    textField.heightAnchor.constraint(equalTo: cell.heightAnchor).isActive = true

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

    guard let uid = item as? UID else {
      NSLog("ERROR [\(treeID)] viewForTableColumn(): not a UID: \(item)")
      return nil
    }

    guard let node = displayStore.getNode(uid) else {
      NSLog("ERROR [\(treeID)] viewForTableColumn(): node not found with UID: \(uid)")
      return nil
    }

    switch identifier.rawValue {
      case "name":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = node.name
        return cell
      case "size":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = StringUtil.formatByteCount(node.sizeBytes)
        return cell
      case "etc":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = String(node.etc)
        return cell
      case "mtime":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = DateUtil.formatTS(node.modifyTS)
        return cell
      case "ctime":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
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
    guard let outlineView = notification.object as? NSOutlineView else {
      return
    }

    var uidSet = Set<UID>()
    for selectedRow in outlineView.selectedRowIndexes {
      if let item = outlineView.item(atRow: selectedRow) {
        if let uid = item as? UID {
          uidSet.insert(uid)
        }
      }
    }
    NSLog("DEBUG [\(treeID)] User selected nodes: \(uidSet)")

    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      do {
        try self.con.backend.setSelectedRowSet(uidSet, self.treeID)
      } catch {
        // Not a serious error: don't show to user
        NSLog("Failed to report node selection: \(error)")
      }
    }
  }

  private func getKey(_ notification: Notification) -> UID? {
    guard let item = notification.userInfo?["NSObject"] else {
      NSLog("ERROR [\(treeID)] getKey(): no item")
      return nil
    }

    guard let uid = item as? UID else {
      NSLog("ERROR [\(treeID)] getKey(): not a UID: \(item)")
      return nil
    }
    return uid
  }

  /**
   EXPAND ROW
  */
  func outlineViewItemWillExpand(_ notification: Notification) {
    guard self.expandContractListenersEnabled else {
      return
    }

    guard let parentUID: UID = getKey(notification) else {
      return
    }
    NSLog("DEBUG [\(treeID)] User expanded node \(parentUID)")

    guard let parentNode = self.displayStore.getNode(parentUID) else {
      self.con.reportError("Could not expand row", "Node not found with UID \(parentUID)")
      return
    }
    do {
      let childList = try self.con.backend.getChildList(parent: parentNode, treeID: self.treeID)

      outlineView.beginUpdates()
      defer {
        outlineView.endUpdates()
      }
      self.displayStore.populateChildList(parentUID, childList)
      self.outlineView.reloadItem(parentUID, reloadChildren: true)
//      self.outlineView.insertItems(at: IndexSet(0...0), inParent: parent, withAnimation: .effectFade)
    } catch {
      self.con.reportException("Failed to expand node", error)
    }
  }

  /**
   COLLAPSE ROW
  */
  func outlineViewItemWillCollapse(_ notification: Notification) {
    guard let parentUID: UID = getKey(notification) else {
      return
    }
    NSLog("DEBUG [\(treeID)] User collapsed node \(parentUID)")

    do {
      try self.con.backend.removeExpandedRow(parentUID, self.treeID)
    } catch {
      NSLog("ERROR Failed to report collapsed node to BE: \(error)")
    }

    let childNodeList = self.displayStore.getChildList(parentUID)
    self.outlineView.reloadItem(parentUID, reloadChildren: true)
//    let rowIndexes = IndexSet.init(integersIn: 0..<childNodeList.count)
//    outlineView.removeItems(at: rowIndexes, inParent: parentUID, withAnimation: .slideLeft)

  }

}
