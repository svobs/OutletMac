import Cocoa
import Foundation
import AppKit
import SwiftUI
import os

let log = OSLog.init(subsystem: "com.msvoboda.Outlet", category: "Root")


final class TreeViewController: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView!
    private let treeController = NSTreeController()
    @objc dynamic var content = [Node]()

    override func viewDidLoad() {
        super.viewDidLoad()

        outlineView.delegate = self

        treeController.objectClass = Node.self
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

        content.append(contentsOf: NodeFactory().nodes())
        
        let prog = "Outlet"
        os_log("Finished loading %{public}@", log: log, type: .error, prog)
    }
}

extension TreeViewController: NSOutlineViewDelegate {
    func bindField(_ outlineView: NSOutlineView, _ identifier: NSUserInterfaceItemIdentifier, _ keyPath: String) -> NSTableCellView? {
        if let view = outlineView.makeView(withIdentifier: identifier, owner: outlineView.delegate) as? NSTableCellView {
            view.textField?.bind(.value,
                                 to: view,
                                 withKeyPath: keyPath,
                                 options: nil)
            return view
        }
        return nil
    }
    
    public func outlineView(_ outlineView: NSOutlineView,
                            viewFor tableColumn: NSTableColumn?,
                            item: Any) -> NSView? {
        var cellView: NSTableCellView?

        guard let identifier = tableColumn?.identifier else { return cellView }

        switch identifier {
        case .init("name"):
            cellView = bindField(outlineView, identifier, "objectValue.name")
        case .init("size_bytes"):
            cellView = bindField(outlineView, identifier, "objectValue.size_bytes")
        case .init("etc"):
            cellView = bindField(outlineView, identifier, "objectValue.etc")
        case .init("modify_ts"):
            cellView = bindField(outlineView, identifier, "objectValue.modify_ts")
        case .init("change_ts"):
            cellView = bindField(outlineView, identifier, "objectValue.change_ts")
        default:
            return cellView
        }
        return cellView
    }
}
//
//struct NodesNSTable: NSViewControllerRepresentable {
//
//    // This is a bridge passing data between the SwiftUI and AppKit worlds
//    @Binding var nodes: Array<Node>?
//
//    typealias NSViewControllerType = TreeViewController
//
//    func makeNSViewController(
//        context: NSViewControllerRepresentableContext<PlayerNSTable>
//    ) -> TreeViewController {
//        return TreeViewController()
//    }
//
//    func updateNSViewController(_ nsViewController: TreeViewController, context: NSViewControllerRepresentableContext<PlayerNSTable>) {
//
//        if let nodes = nodes {
//            nsViewController.refresh(nodes)
//        }
//
//        return
//
//    }
//
//}
//
//struct PlayerTable: View {
//
//    @State var players: Array<Node>? = nil
//
//    var body: some View {
//        PlayerNSTable(
//            players: self.$players
//        )
//            .frame(alignment: .topLeading)
//            .onAppear(perform: retrievePlayers)
//    }
//
//    func retrievePlayers() -> Void {
//        self.players = nil
//        Player.retrieveMany(
//            season: Season(publicId: "2020")
//        ) { (error, players) in
//            guard let players = players else {
//                fatalError("No players")
//            }
//            self.players = players
//        }
//    }
//}
