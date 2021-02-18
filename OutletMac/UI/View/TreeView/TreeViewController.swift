import Cocoa
import AppKit
import SwiftUI
import Foundation

/// Representation of a row in the outline view
struct OutlineViewRow {
  var key: String
  var value: Any?
  var children = [OutlineViewRow]()

  static func rowsFrom( node: TreeViewNode) -> [OutlineViewRow] {
    return [
      OutlineViewRow(key: "node", value: node.value),
      OutlineViewRow(key: "count", value: node.childrenCount)
    ]
  }
}

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
 
 */
final class TreeViewController: NSViewController, NSOutlineViewDelegate {
//  @IBOutlet weak var outlineView: NSOutlineView!
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
//    outlineView.dataSource = self

    // TreeController
    treeController.objectClass = TreeViewNode.self
    treeController.childrenKeyPath = "children"
    treeController.countKeyPath = "count"
    treeController.leafKeyPath = "isLeaf"

    treeController.bind(NSBindingName(rawValue: "contentArray"),
                        to: self,
                        withKeyPath: "content",
                        options: nil)


    outlineView.bind(NSBindingName(rawValue: "content"),
                     to: treeController,
                     withKeyPath: "arrangedObjects",
                     options: nil)

    content.append(contentsOf: self.nodes)
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

    switch identifier.rawValue {
      case "node":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.bind(.value, to: view, withKeyPath: "objectValue.value", options: nil)
        return cell
      case "count":
        var cell = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeCell(withIdentifier: identifier)
        }
        cell!.textField!.bind(.value, to: view, withKeyPath: "objectValue.childrenCount", options: nil)
        return cell
      default:
        NSLog("ERROR unrecognized identifier (ignoring): \(identifier.rawValue)")
        return nil
    }
  }
}
