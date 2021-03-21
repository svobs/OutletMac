//
//  TreePanel.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

/**
 STRUCT TreePanel

 Just a container for all the components for a given tree
 */
struct TreePanel {
  let app: OutletApp
  let con: TreeControllable
  let rootPathPanel: RootPathPanel
  let filterPanel: FilterPanel
  let treeView: TreeView
  let status_panel: StatusPanel

  init(_ app: OutletApp, _ controller: TreeControllable) {
    self.app = app
    self.con = controller
    self.rootPathPanel = RootPathPanel(self.con, canChangeRoot: true)
    self.filterPanel = FilterPanel(self.con)
    self.treeView = TreeView(controller: self.con)
    self.status_panel = StatusPanel(controller: self.con)
  }
}

/**
 STRUCT StatusPanel
 */
struct StatusPanel: View {
  @ObservedObject var swiftTreeState: SwiftTreeState

  init(controller: TreeControllable) {
    self.swiftTreeState = controller.swiftTreeState
  }

  var body: some View {
    HStack {
      Text(self.swiftTreeState.statusBarMsg)
        .multilineTextAlignment(.leading)
        .font(Font.system(.body))
      Spacer()
    }
    .padding(.leading, H_PAD)
  }
}
