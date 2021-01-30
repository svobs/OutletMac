import Cocoa
import AppKit
import SwiftUI
import Foundation

struct TreeViewRepresentable: NSViewControllerRepresentable {

  func makeNSViewController(context: Context) -> TreeViewController {
    return TreeViewController()
  }
  
  func updateNSViewController(_ nsViewController: TreeViewController, context: Context) {
    return
  }
}

/*
 See: https://www.appcoda.com/macos-programming-nsoutlineview/
 
 */
final class TreeViewController: NSViewController {
  @IBOutlet weak var outlineView: NSOutlineView!
  private let treeController = NSTreeController()
  @objc dynamic var content = [TreeViewNode]()

  override func viewDidLoad() {
    super.viewDidLoad()

    outlineView.delegate = self

    treeController.objectClass = TreeViewNode.self

    treeController.childrenKeyPath = "children"
    treeController.countKeyPath = "count"
    treeController.leafKeyPath = "isLeaf"

    outlineView.gridStyleMask = .solidHorizontalGridLineMask
    outlineView.autosaveExpandedItems = true

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
}

extension TreeViewController: NSOutlineViewDelegate {
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
