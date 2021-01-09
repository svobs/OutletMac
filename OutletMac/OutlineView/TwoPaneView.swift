//
//  TwoPaneView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 1/6/21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

let SPACING_V: CGFloat = 10
let SPACING_H: CGFloat = 10

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

struct RootDirPanel: View {
    var body: some View {
        TodoPlaceholder("<TODO: RootDirPanel>")
    }
}

struct FilterPanel: View {
    var body: some View {
        TodoPlaceholder("<TODO: FilterPanel>")
    }
}

struct TreeView: View {
    var body: some View {
        TodoPlaceholder("<TODO: TreeView>")
    }
}

struct StatusPanel: View {
    var body: some View {
        TodoPlaceholder("<Status msg panel>")
    }
}

struct TreePanel {
    let root_dir_panel = RootDirPanel()
    let filter_panel = FilterPanel()
    let tree_view = TreeView()
    let status_panel = StatusPanel()
}

@available(OSX 11.0, *)
struct TwoPaneView: View {
    private var columns: [GridItem] = [
        // these specify spacing between columns
        GridItem(.flexible(minimum: 300), spacing: SPACING_H),
        GridItem(.flexible(minimum: 300), spacing: SPACING_H),
    ]
    
    private var left_tree_panel = TreePanel()
    private var right_tree_panel = TreePanel()
    
    private var leftItemList: [Int]
    
    private var rightItemList: [Int]
    
    init(_ leftItemList: [Int], _ rightItemList: [Int]) {
        self.leftItemList = leftItemList
        self.rightItemList = rightItemList
    }
    private var symbols = ["keyboard", "hifispeaker.fill", "printer.fill", "tv.fill", "desktopcomputer", "headphones", "tv.music.note", "mic", "plus.bubble", "video"]
    private var colors: [Color] = [.yellow, .purple, .green]

    
    var body: some View {
//        ScrollView(.vertical) {
            LazyVGrid(
                columns: columns,
                alignment: .center,
                spacing: SPACING_V
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
        let cells_left:[Int] = [2]
        let cells_right:[Int] = [4]
        TwoPaneView(cells_left, cells_right)
    }
}
