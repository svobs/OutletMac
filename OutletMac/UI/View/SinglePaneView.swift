//
//  SinglePaneView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/21.
//

import SwiftUI

/**
 STRUCT SinglePaneView

 Note: currently this is just a single-column version of TwoPaneView, with the button & progresss row removed
 (if it works, why add effort and bugs?)
 */
struct SinglePaneView: View {
  @EnvironmentObject var settings: GlobalSettings
  @ObservedObject var heightTracking: HeightTracking

  private var columns: [GridItem] = [
    // these specify spacing between columns
    // note: min width must be set here, so that toolbars don't get squished
    GridItem(.flexible(minimum: 400, maximum: .infinity), spacing: H_PAD),
  ]

  let app: OutletApp
  let con: TreePanelControllable

  var treePanel: TreePanel! = nil

  init(_ app: OutletApp, _ con: TreePanelControllable, _ heightTracking: HeightTracking) {
    self.app = app
    self.con = con
    self.heightTracking = heightTracking
    self.treePanel = TreePanel(app, con, self.heightTracking)
  }

  var body: some View {
    LazyVGrid(
      columns: columns,
      alignment: .leading,
      spacing: 0  // no vertical spacing between cells
    ) {
      // Row0: Root Path
      self.treePanel.rootPathPanel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Root", col: 0, height: geo.size.height))
        })

      // Row1: filter panel
      self.treePanel.filterPanel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Filter", col: 0, height: geo.size.height))
        })

      // Row2: Tree view
      self.treePanel.treeView

      // Row3: Status msg
      self.treePanel.status_panel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Status", col: 0, height: geo.size.height))
        })

    } // end of LazyVGrid
    .onPreferenceChange(MyHeightPreferenceKey.self) { key in
      var totalHeight: CGFloat = 0
      for height0 in key.col0.values {
        totalHeight += height0
      }
//      NSLog("SIZES: \(key.col0), \(key.col1)")
//      NSLog("TOTAL HEIGHT: \(totalHeight) (subtract from \(settings.mainWindowHeight))")
      self.heightTracking.nonTreeViewHeight = totalHeight
    }
  }
}
