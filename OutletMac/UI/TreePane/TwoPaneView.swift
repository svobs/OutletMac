//
//  TwoPaneView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 1/6/21.
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
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

}

/**
 STRUCT ButtonBar
 TODO: convert to toolbar buttons & menu items, then delete
 */
fileprivate struct ButtonBar: View {
  @EnvironmentObject var globalState: GlobalState
  let app: OutletAppProtocol
  let conLeft: TreeControllable
  let conRight: TreeControllable

  init(app: OutletAppProtocol, conLeft: TreeControllable, conRight: TreeControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
    NSLog("INFO  DONE loading ButtonBar")
  }

  var body: some View {
    HStack {
      if globalState.mode == .BROWSING {
        Button("Diff (content-first)", action: {
          NSApp.sendAction(AppMainMenu.DIFF_TREES_BY_CONTENT, to: self.app, from: self)
        })
          .disabled(!self.globalState.isUIEnabled)
      } else if globalState.mode == .DIFF {
        Button("Merge...", action: {
          NSApp.sendAction(AppMainMenu.MERGE_CHANGES, to: self.app, from: self)
        })
          .disabled(!self.globalState.isUIEnabled)
        Button("Cancel Diff", action: {
          NSApp.sendAction(AppMainMenu.CANCEL_DIFF, to: self.app, from: self)
        })
          .disabled(!self.globalState.isUIEnabled)
      }
      PlayPauseToggleButton(app.iconStore, conLeft.dispatcher)
      Spacer()
    }
    .padding(.leading, H_PAD)
    .buttonStyle(BorderedButtonStyle())
  }

}

/**
 STRUCT TwoPaneView

 This forms almost all (or all?) of the content for the main window
 */
struct TwoPaneView: View {
  @EnvironmentObject var globalState: GlobalState
  @ObservedObject var windowState: WindowState

  private var columns: [GridItem] = [
    // these specify spacing between columns
    // note: min width must be set here, so that toolbars don't get squished
    GridItem(.flexible(minimum: 400, maximum: .infinity), spacing: H_PAD),
    GridItem(.flexible(minimum: 400, maximum: .infinity), spacing: H_PAD),
  ]

  let app: OutletAppProtocol
  let conLeft: TreeControllable
  let conRight: TreeControllable

  init(app: OutletAppProtocol, conLeft: TreeControllable, conRight: TreeControllable, _ windowState: WindowState) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
    self.windowState = windowState
  }

  var body: some View {
    LazyVGrid(
      columns: columns,
      alignment: .leading,
      spacing: 0  // no vertical spacing between cells
    ) {
      // Row0: Root Path
      RootPathPanel(self.conLeft)
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Root", col: 0, height: geo.size.height))
        })
      RootPathPanel(self.conRight)
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Root", col: 1, height: geo.size.height))
        })

      // Row1: filter panel
      FilterPanel(self.conLeft)
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Filter", col: 0, height: geo.size.height))
        })
      FilterPanel(self.conRight)
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Filter", col: 1, height: geo.size.height))
        })

      // Row2: Tree view
      TreeView(controller: self.conLeft, windowState)
      TreeView(controller: self.conRight, windowState)

      // Row3: Status msg
      StatusPanel(self.conLeft)
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Status", col: 0, height: geo.size.height))
        })
      StatusPanel(self.conRight)
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Status", col: 1, height: geo.size.height))
        })

      // Row4: Button bar & progress bar
      ButtonBar(app: self.app, conLeft: self.conLeft, conRight: self.conRight)
        .frame(alignment: .bottomLeading)
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Bot", col: 0, height: geo.size.height))
        })

        HStack {
          Spacer()
          TodoPlaceholder("TODO: progress bar")
            .frame(alignment: .bottomTrailing)
        }
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Bot", col: 1, height: geo.size.height))
        })
    } // end of LazyVGrid
    .onPreferenceChange(MyHeightPreferenceKey.self) { key in
      var totalHeight: CGFloat = 0
      for (name, height0) in key.col0 {
        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG TwoPaneView sizes: \(key.col0), \(key.col1)")
        }
        let height1 = key.col1[name] ?? 0
        totalHeight += max(height0, height1)
      }
      if SUPER_DEBUG_ENABLED {
        NSLog("DEBUG TwoPaneView TotalHeight: \(totalHeight) (subtract from \(self.windowState.windowHeight))")
      }
      self.windowState.nonTreeViewHeight = totalHeight
    }
  }
}
