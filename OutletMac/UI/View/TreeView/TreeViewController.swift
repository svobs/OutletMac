import Cocoa
import AppKit
import SwiftUI
import Foundation

struct TreeViewRepresentable: NSViewControllerRepresentable {
  // TODO: @Binding var nodes: Array<Node>?

  func makeNSViewController(context: Context) -> TreeViewController {
    return TreeViewController()
  }
  
  func updateNSViewController(_ nsViewController: TreeViewController, context: Context) {
    // TODO: apply updates here
    NSLog("TreeView update requested!")
    return
  }
}

/*
 See: https://www.appcoda.com/macos-programming-nsoutlineview/
 See: https://stackoverflow.com/questions/45373039/how-to-program-a-nsoutlineview
 */
final class TreeViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
  private let treeController = NSTreeController()
  @objc dynamic var content = [TreeViewNode]()
  let scrollView = NSScrollView()
  let outlineView = NSOutlineView()

  var nodes: [TreeViewNode] = []

  override func loadView() {
      let rect = NSRect(x: 0, y: 0, width: 400, height: 400)
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

    nodes =  TreeViewNodeFactory().nodes()

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

  // You must give each row a unique identifier, referred to as `item` by the outline view
  //   * For top-level rows, we use the values in the `keys` array
  //   * For the hobbies sub-rows, we label them as ("hobbies", 0), ("hobbies", 1), ...
  //     The integer is the index in the hobbies array
  //
  // item == nil means it's the "root" row of the outline view, which is not visible
  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if item == nil {
//      return keys[index]
      // [Matt]: just use index into nodes for now
      return String(index)

      // FIXME: this breaks for nested nodes. Just switch to using nodes with UIDs


//    } else if let item = item as? String, item == "hobbies" {
//      return ("hobbies", index)
    } else {
      return 0
    }
  }

  // Tell how many children each row has:
  //    * The root row has 5 children: name, age, birthPlace, birthDate, hobbies
  //    * The hobbies row has how ever many hobbies there are
  //    * The other rows have no children
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if item == nil {
      // Root
      return self.nodes.count
    } else if let item = item as? String {
      return nodes[Int(item)!].count
    } else {
      return 0
    }
  }

  // Tell whether the row is expandable
  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    if let item = item as? String, nodes[Int(item)!].count > 0 {
      return true
    } else {
      return false
    }
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

  /**
   Makes contents of the cell
   From NSOutlineViewDelegate
   */
  public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let identifier = tableColumn?.identifier else { return nil }

    guard let uidStr = item as? String else {
      NSLog("ERROR viewForTableColumn(): item is not a String: \(item)")
      return nil
    }
    guard let uid = Int(uidStr) else {
      NSLog("ERROR viewForTableColumn(): could not parse as int: \(uidStr)")
      return nil
    }

    switch identifier.rawValue {
      case "node":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = self.nodes[uid].value
        return cell
      case "count":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = self.nodes[uid].childrenCount
        return cell
      default:
        NSLog("ERROR unrecognized identifier (ignoring): \(identifier.rawValue)")
        return nil
    }
  }
}
