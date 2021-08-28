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
  weak var app: OutletApp!
  let con: TreePanelControllable
  let treeView: TreeView

  init(_ app: OutletApp, _ controller: TreePanelControllable, _ heightTracking: WindowState) {
    self.app = app
    self.con = controller
    self.treeView = TreeView(controller: self.con, heightTracking)
  }
}

/**
 STRUCT StatusPanel
 */
struct StatusPanel: View {
  @ObservedObject var swiftTreeState: SwiftTreeState

  init(_ controller: TreePanelControllable) {
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
