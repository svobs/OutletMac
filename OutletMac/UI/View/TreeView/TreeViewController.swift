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
 
 */
final class TreeViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
//  @IBOutlet weak var outlineView: NSOutlineView!
  private let treeController = NSTreeController()
  @objc dynamic var content = [TreeViewNode]()
  let scrollView = NSScrollView()
  let outlineView = NSOutlineView()

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
    nodeColumn.dataCell = NSTextFieldCell()
    outlineView.addTableColumn(nodeColumn)


    let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "count"))
    countColumn.title = "Count"
    countColumn.width = 100
    countColumn.minWidth = 100
    countColumn.dataCell = NSTextFieldCell()
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

    content.append(contentsOf: TreeViewNodeFactory().nodes())
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          viewFor tableColumn: NSTableColumn?,
                          item: Any) -> NSView? {
    var cellView: NSTableCellView?

    guard let identifier = tableColumn?.identifier else { return cellView }

    switch identifier {
      case .init("node"):
        if let view = outlineView.makeView(withIdentifier: identifier,
                                           owner: outlineView.delegate) as? NSTableCellView {
          view.textField?.bind(.value,
                               to: view,
                               withKeyPath: "objectValue.value",
                               options: nil)
          cellView = view
        }
      case .init("count"):
        if let view = outlineView.makeView(withIdentifier: identifier,
                                           owner: outlineView.delegate) as? NSTableCellView {
          view.textField?.bind(.value,
                               to: view,
                               withKeyPath: "objectValue.childrenCount",
                               options: nil)
          cellView = view
        }
      default:
        return cellView
    }
    return cellView
  }
}
