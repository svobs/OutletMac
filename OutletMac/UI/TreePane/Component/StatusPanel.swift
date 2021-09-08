//
//  TreePanel.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

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
