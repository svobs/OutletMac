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
  @ObservedObject var swiftFilterState: SwiftFilterState
  let con: TreeControllable

  init(controller: TreeControllable) {
    self.con = controller
    self.swiftFilterState = controller.swiftFilterState
  }

  var body: some View {
    HStack(spacing: H_PAD) {
      TextField("Filter by name", text: $swiftFilterState.searchQuery, onEditingChanged: { (editingChanged) in
        if editingChanged {
          // TODO
        } else {
          // This is ENTER key
        }
      })
      .cornerRadius(6.0)
      .font(Font.system(.title))
      .frame(minWidth: 180, maxWidth: .infinity)
      .padding(.leading, H_PAD)

      // Show ancestors
      BoolToggleButton($swiftFilterState.showAncestors, imageName: "FolderTree")

      // Match Case
      BoolToggleButton($swiftFilterState.isMatchCase, systemImageName: "textformat")

      // Is Trashed
      TernaryToggleButton($swiftFilterState.isTrashed, systemImageName: "trash")

      // Is Shared
      TernaryToggleButton($swiftFilterState.isShared, imageName: "Shared")
    }
    .padding(.bottom, V_PAD)
    .padding(.top, V_PAD)
    .frame(minWidth: 200,
           maxWidth: .infinity,
           alignment: .topLeading)
  }
}

struct FilterPanel_Previews: PreviewProvider {
  static var previews: some View {
    FilterPanel(controller: MockTreeController(ID_LEFT_TREE))
  }
}

