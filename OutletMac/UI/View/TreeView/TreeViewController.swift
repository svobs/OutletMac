import Cocoa
import AppKit
import SwiftUI
import Foundation

/**
 TreeViewRepresentable: SwiftUI wrapper for TreeView
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

/*
 See: https://www.appcoda.com/macos-programming-nsoutlineview/
 See: https://stackoverflow.com/questions/45373039/how-to-program-a-nsoutlineview
 */
final class TreeViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
  // Cannot override init(), but this must be set manually before loadView() is called
  var con: TreeControllable? = nil

  private let treeController = NSTreeController()
  let scrollView = NSScrollView()
  let outlineView = NSOutlineView()

  var displayStore: DisplayStore {
    return self.con!.displayStore
  }

  // NSViewController methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  override func loadView() {
    guard self.con != nil else {
      fatalError("[\(self.con!.treeID)] loadView(): TreeViewController has no TreeControllable set!")
    }
    NSLog("DEBUG [\(self.con!.treeID)] loadView(): setting TreeViewController in TreeController")
    self.con!.connectTreeView(self)

    // TODO: does this do anything??
    let rect = NSRect(x: 0, y: 0, width: 600, height: 600)
    view = NSView(frame: rect)
  }

  private func setUpOutlineView() {
    outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
    outlineView.allowsMultipleSelection = true
    outlineView.autosaveTableColumns = true
    outlineView.autosaveExpandedItems = true
    outlineView.rowSizeStyle = .large
    outlineView.indentationPerLevel = 16
    outlineView.backgroundColor = .clear
    outlineView.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)

    outlineView.headerView = NSTableHeaderView()
    let nodeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "node"))
    nodeColumn.title = "Nodes"
    nodeColumn.width = 200
    nodeColumn.minWidth = 100
    outlineView.addTableColumn(nodeColumn)


    let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "count"))
    countColumn.title = "Count"
    countColumn.width = 100
    countColumn.minWidth = 100
    outlineView.addTableColumn(countColumn)

    outlineView.gridStyleMask = .solidHorizontalGridLineMask
    outlineView.autosaveExpandedItems = true
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // OutlineView
    self.setUpOutlineView()

    // ScrollView
    self.view.addSubview(scrollView)
    self.scrollView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addConstraint(NSLayoutConstraint(item: self.scrollView, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0))
    self.view.addConstraint(NSLayoutConstraint(item: self.scrollView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 23))
    self.view.addConstraint(NSLayoutConstraint(item: self.scrollView, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 0))
    self.view.addConstraint(NSLayoutConstraint(item: self.scrollView, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: 0))
    scrollView.backgroundColor = NSColor.clear
    scrollView.drawsBackground = false
    scrollView.documentView = outlineView
    scrollView.hasHorizontalScroller = false
    scrollView.hasVerticalScroller = true
    scrollView.horizontalPageScroll = 10
    scrollView.verticalLineScroll = 19
    scrollView.verticalPageScroll = 10

    outlineView.frame = scrollView.bounds
    outlineView.delegate = self
    outlineView.dataSource = self
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
      NSLog("ERROR [\(self.con!.treeID)] viewForTableColumn(): not a UID: \(item)")
      return nil
    }

    let nodeOpt: Node? = displayStore.treeNodeDict[uid]
    guard nodeOpt != nil else {
      NSLog("ERROR [\(self.con!.treeID)] viewForTableColumn(): node not found with UID: \(uid)")
      return nil
    }
    let node = nodeOpt!

    switch identifier.rawValue {
      case "node":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = node.name
        return cell
      case "count":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = String(node.sizeBytes ?? 0)
        return cell
      default:
        NSLog("ERROR [\(self.con!.treeID)] unrecognized identifier (ignoring): \(identifier.rawValue)")
        return nil
    }
  }

  func outlineViewSelectionDidChange(_ notification: Notification) {
    //1
    guard let outlineView = notification.object as? NSOutlineView else {
      return
    }
    //2
    let selectedIndex = outlineView.selectedRow
    if let item = outlineView.item(atRow: selectedIndex) as? String {
//      //3
//      let url = URL(string: feedItem.url)
//      //4
//      if let url = url {
//        //5
//        self.webView.mainFrame.load(URLRequest(url: url))
//      }
    }
  }
}
