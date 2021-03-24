//
//  FilterPanel.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-31.
//
import SwiftUI

/*
extension NSTextField {
  // Workaround to get rid of focus ring in all text fields
  open override var focusRingType: NSFocusRingType {
    get { .none }
    set { }
  }
}
 */

/**
 MacOS's default text field is just a wrapper for NSTextField, which is archaic and minimally ocnfigurable. This is an attempt to clean it up
 and give it a slightly better look.
 */
struct FancyTextField: View {
  let titleKey: LocalizedStringKey
  let text: Binding<String>
  let onEditingChanged: (Bool) -> Void
  let onCommit: () -> Void

  init(_ titleKey: LocalizedStringKey, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void = { _ in }, onCommit: @escaping () -> Void = {}) {
    self.titleKey = titleKey
    self.text = text
    self.onEditingChanged = onEditingChanged
    self.onCommit = onCommit
  }

  var body: some View {
    HStack {
      HStack {
        TextField("Filter by name", text: text, onEditingChanged: onEditingChanged, onCommit: onCommit)
        .textFieldStyle(PlainTextFieldStyle())
        .font(FILTER_ENTRY_FONT)
        .frame(minWidth: 180, maxWidth: .infinity)
      }
      .padding(2)
      .background(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary))
      //      .shadow(color: .primary, radius: 2)
    }
    .padding(H_PAD)
  }
}

/**
 STRUCT FilterPanel

 Reminder: use the "SF Symbols" app to browse Mac OS system icons
 */
struct FilterPanel: View {
  @ObservedObject var swiftFilterState: SwiftFilterState
  let con: TreeControllable

  init(_ controller: TreeControllable) {
    self.con = controller
    self.swiftFilterState = controller.swiftFilterState
  }

  var body: some View {
    HStack(spacing: H_PAD) {
      FancyTextField("Filter by name", text: $swiftFilterState.searchQuery, onEditingChanged: { (editingChanged) in
        if editingChanged {
          // TODO
        } else {
          // This is ENTER key
        }
      })

      // Show ancestors
      BoolToggleButton(con.app.iconStore, iconTrue: .ICON_FOLDER_TREE, $swiftFilterState.showAncestors)

      // Match Case
      BoolToggleButton(con.app.iconStore, iconTrue: .ICON_MATCH_CASE, $swiftFilterState.isMatchCase)

      // Is Trashed
      TernaryToggleButton(con.app.iconStore, iconTrue: .ICON_IS_TRASHED, iconFalse: .ICON_IS_NOT_TRASHED, $swiftFilterState.isTrashed)

      // Is Shared
      TernaryToggleButton(con.app.iconStore, iconTrue: .ICON_IS_SHARED, iconFalse: .ICON_IS_NOT_SHARED, $swiftFilterState.isShared)
    }
    .padding(.bottom, 0)
    .padding(.top, 0)
    .frame(minWidth: 200,
           maxWidth: .infinity,
           alignment: .topLeading)
//    .background(Color.purple)  // TODO
  }
}

struct FilterPanel_Previews: PreviewProvider {
  static let app = MockApp()
  static var previews: some View {
    FilterPanel(MockTreeController(ID_LEFT_TREE, canChangeRoot: true))
  }
}

