import AppKit
import SwiftUI

/**
 TreeView: enclosing SwiftUI view to specify layout
 */
struct TreeView: View {
  let con: TreeControllable
  @EnvironmentObject var globalState: GlobalState
  @ObservedObject var swiftTreeState: SwiftTreeState
  @ObservedObject var windowState: WindowState

  init(controller: TreeControllable, _ windowState: WindowState) {
    self.con = controller
    self.swiftTreeState = self.con.swiftTreeState
    self.windowState = windowState
  }

  private func makeTreeView() -> some View {
      TreeViewRepresentable(controller: self.con)
        .padding(.top)
        .frame(minWidth: 200,
               maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               // A redraw of this view should be triggered when either of these values are changed:
               minHeight: windowState.getTreeViewHeight(),
               maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               alignment: .topLeading)
  }

  var body: some View {
    HStack {
      // Here we really want to just wipe out the NSOutlineView and rebuild it from scratch if the
      // value of 'hasCheckboxes' changes. This accomplishes that in an almost-clean way:
      if swiftTreeState.hasCheckboxes {
        makeTreeView()
      } else {
        makeTreeView()
      }
    }
    .frame(alignment: .topLeading)
  }
}

/**
 TreeViewRepresentable: SwiftUI wrapper for NSOutlineView
 */
fileprivate struct TreeViewRepresentable: NSViewControllerRepresentable {
  let con: TreeControllable

  init(controller: TreeControllable) {
    self.con = controller
  }

  func makeNSViewController(context: Context) -> TreeNSViewController {
    NSLog("DEBUG [\(self.con.treeID)] Creating TreeNSViewController")
    let treeViewController = TreeNSViewController()
    treeViewController.con = self.con
    return treeViewController
  }
  
  func updateNSViewController(_ nsViewController: TreeNSViewController, context: Context) {
    // Apply updates here?
    NSLog("DEBUG [\(self.con.treeID)] TreeView update requested")
  }
}
