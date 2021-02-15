//
//  FilterPanel.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-31.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI

/**
 STRUCT FilterPanel

 Reminder: use the "SF Symbols" app to browse Mac OS system icons
 */
struct FilterPanel: View {
  @ObservedObject var uiState: TreeSwiftState
  let con: TreeControllable

  init(controller: TreeControllable) {
    self.con = controller
    self.uiState = controller.uiState
  }

  var body: some View {
    HStack(spacing: H_PAD) {
      TextField("Filter by name", text: $uiState.rootPath, onEditingChanged: { (editingChanged) in
        if editingChanged {
          // TODO
        } else {
          // This is ENTER key
        }
      })
      .font(Font.system(.title))

      // Show ancestors
      TernaryToggleButton(.FALSE, imageName: "folder.fill")

      // Match Case
      TernaryToggleButton(.TRUE, imageName: "textformat")

      // Is Trashed
      TernaryToggleButton(.FALSE, imageName: "trash")

      // Is Shared
      TernaryToggleButton(.FALSE, imageName: "person.2.fill")
    }
    .padding(.bottom, V_PAD)
    .padding(.top, V_PAD)
  }
}

struct FilterPanel_Previews: PreviewProvider {
  static var previews: some View {
    FilterPanel(controller: MockTreeController(ID_LEFT_TREE))
  }
}

