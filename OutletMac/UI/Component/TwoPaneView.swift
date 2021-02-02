//
//  TwoPaneView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 1/6/21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

struct TodoPlaceholder: View {
  let msg: String
  init(_ msg: String) {
    self.msg = msg
  }

  var body: some View {
    ZStack {
      Rectangle().fill(Color.green)
      Text(msg)
        .foregroundColor(Color.black)
    } .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

}

/**
 STRUCT TreeView
 */
struct TreeView: View {
  
  var outlineTree: OutlineTree<ExampleClass, [ExampleClass]>
  @State var selectedItem: OutlineNode<ExampleClass>? = nil
  
  init(items: [ExampleClass]) {
    outlineTree = OutlineTree(representedObjects: items)
  }
  
  var body: some View {
    OutlineSection<ExampleClass, [ExampleClass]>(selectedItem: $selectedItem).environmentObject(outlineTree)
      .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
  }
}

/**
 STRUCT StatusPanel
 */
struct StatusPanel: View {
  var body: some View {
    TodoPlaceholder("<Status msg panel>")
  }
}

/**
 STRUCT TreePanel
 */
struct TreePanel {
  let con: TreeControllable
  let root_dir_panel: RootDirPanel
  let filter_panel: FilterPanel
  let tree_view: TreeView
  let status_panel: StatusPanel

  init(controller: TreeControllable) {
    self.con = controller
    self.root_dir_panel = RootDirPanel(controller: self.con, canChangeRoot: true)
    self.filter_panel = FilterPanel()
    self.tree_view = TreeView(items:  exampleArray())
    self.status_panel = StatusPanel()
  }
}

/**
 STRUCT TwoPaneView
 */
@available(OSX 11.0, *)
struct TwoPaneView: View {
  private var columns: [GridItem] = [
    // these specify spacing between columns
    GridItem(.flexible(minimum: 300), spacing: H_PAD),
    GridItem(.flexible(minimum: 300), spacing: H_PAD),
  ]

  let backend: OutletBackend
  let conLeft: TreeControllable
  let conRight: TreeControllable
  let left_tree_panel: TreePanel
  let right_tree_panel: TreePanel

  init(backend: OutletBackend, conLeft: TreeControllable, conRight: TreeControllable) {
    self.backend = backend
    self.conLeft = conLeft
    self.conRight = conRight
    self.left_tree_panel = TreePanel(controller: conLeft)
    self.right_tree_panel = TreePanel(controller: conRight)
  }

  private var symbols = ["keyboard", "hifispeaker.fill", "printer.fill", "tv.fill", "desktopcomputer", "headphones", "tv.music.note", "mic", "plus.bubble", "video"]
  private var colors: [Color] = [.yellow, .purple, .green]


    var body: some View {
//        ScrollView(.vertical) {
            LazyVGrid(
                columns: columns,
                alignment: .center,
                spacing: V_PAD
//                pinnedViews: [.sectionHeaders, .sectionFooters]
            ) {
//                ForEach((0...10), id: \.self) {
//                    Image(systemName: symbols[$0 % symbols.count])
//                        .font(.system(size: 30))
//                        .frame(width: 50, height: 50)
//                        .background(colors[$0 % colors.count])
//                        .cornerRadius(10)
//                }
                self.left_tree_panel.root_dir_panel
                self.right_tree_panel.root_dir_panel
                
                self.left_tree_panel.filter_panel
                self.right_tree_panel.filter_panel
                
                self.left_tree_panel.tree_view//.frame(maxWidth: .infinity, maxHeight: .infinity)
                self.right_tree_panel.tree_view//.frame(maxWidth: .infinity, maxHeight: .infinity)
                
                
                self.left_tree_panel.status_panel
                self.right_tree_panel.status_panel
                
                // TODO: move these out into a separate view, and out of the grid
                TodoPlaceholder("<BUTTON BAR>")
                TodoPlaceholder("<PROGRESS BAR>")
                
//                Section(header: Text("Section 1").font(.title)) {
//                    self.leftItemList.forEach {
//                        Rectangle().fill(Color.green)
//                        print($0)
//                    }
//                }
            }.frame(width: 800, height: 500)
//        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@available(OSX 11.0, *)
struct TwoPaneView_Previews: PreviewProvider {
  static var previews: some View {
    TwoPaneView(backend: NullBackend(), conLeft: NullTreeController(ID_LEFT_TREE), conRight: NullTreeController(ID_RIGHT_TREE))
  }
}
