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
 */
fileprivate struct ButtonBar: View {
  @EnvironmentObject var settings: GlobalSettings
  let app: OutletApp
  let conLeft: TreePanelControllable
  let conRight: TreePanelControllable

  init(app: OutletApp, conLeft: TreePanelControllable, conRight: TreePanelControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
  }

  var body: some View {
    HStack {
      if settings.mode == .BROWSING {
        Button("Diff (content-first)", action: self.onDiffButtonClicked)
        Button("Download Google Drive meta", action: self.onDownloadFromGDriveButtonClicked)
      } else if settings.mode == .DIFF {
        Button("Merge...", action: self.onMergeButtonClicked)
        Button("Cancel Diff", action: self.onCancelDiffButtonClicked)
      }
      PlayPauseToggleButton(app.iconStore, conLeft.dispatcher)
      Spacer()
    }
    .padding(.leading, H_PAD)
    .buttonStyle(BorderedButtonStyle())
  }

  // UI callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func onDiffButtonClicked() {
    NSLog("DEBUG Diff btn clicked! Sending request to BE to diff trees '\(self.conLeft.treeID)' & '\(self.conRight.treeID)'")

    // First disable UI
    self.app.sendEnableUISignal(enable: false)

    // Now ask BE to start the diff
    do {
      _ = try self.conLeft.backend.startDiffTrees(treeIDLeft: self.conLeft.treeID, treeIDRight: self.conRight.treeID)
      //  We will be notified asynchronously when it is done/failed. If successful, the old tree_ids will be notified and supplied the new IDs
    } catch {
      NSLog("ERROR Failed to start tree diff: \(error)")
      self.app.sendEnableUISignal(enable: true)
    }
  }

  func onDownloadFromGDriveButtonClicked() {
    NSLog("DEBUG DownloadGDrive btn clicked! Sending signal: '\(Signal.DOWNLOAD_ALL_GDRIVE_META)'")
    self.conLeft.dispatcher.sendSignal(signal: .DOWNLOAD_ALL_GDRIVE_META, senderID: ID_MAIN_WINDOW)
  }

  func onMergeButtonClicked() {
    do {
      let selectedChangeListLeft = try self.conLeft.generateCheckedRowList()
      let selectedChangeListRight = try self.conRight.generateCheckedRowList()

      let guidListLeft: [GUID] = selectedChangeListLeft.map({ $0.spid.guid })
      let guidListRight: [GUID] = selectedChangeListRight.map({ $0.spid.guid })
      if SUPER_DEBUG {
        NSLog("INFO  Selected changes (Left): [\(selectedChangeListLeft.map({ "\($0.spid)" }).joined(separator: "  "))]")
        NSLog("INFO  Selected changes (Right): [\(selectedChangeListRight.map({ "\($0.spid)" }).joined(separator: "  "))]")
      }

      self.app.sendEnableUISignal(enable: false)

      try self.app.backend.generateMergeTree(treeIDLeft: self.conLeft.treeID, treeIDRight: self.conRight.treeID,
                                             selectedChangeListLeft: guidListLeft, selectedChangeListRight: guidListRight)

    } catch {
      self.conLeft.reportException("Failed to generate merge preview", error)
      self.app.sendEnableUISignal(enable: true)
    }
  }

  func onCancelDiffButtonClicked() {
    NSLog("DEBUG CancelDiff btn clicked! Sending signal: '\(Signal.EXIT_DIFF_MODE)'")
    self.conLeft.dispatcher.sendSignal(signal: .EXIT_DIFF_MODE, senderID: ID_MAIN_WINDOW)
  }
}

/**
 STRUCT TwoPaneView

 This forms almost all (or all?) of the content for the main window
 */
struct TwoPaneView: View {
  @EnvironmentObject var settings: GlobalSettings
  @ObservedObject var heightTracking: HeightTracking

  private var columns: [GridItem] = [
    // these specify spacing between columns
    // note: min width must be set here, so that toolbars don't get squished
    GridItem(.flexible(minimum: 400, maximum: .infinity), spacing: H_PAD),
    GridItem(.flexible(minimum: 400, maximum: .infinity), spacing: H_PAD),
  ]

  let app: OutletApp
  let conLeft: TreePanelControllable
  let conRight: TreePanelControllable
  let leftPanel: TreePanel
  let rightPanel: TreePanel

  init(app: OutletApp, conLeft: TreePanelControllable, conRight: TreePanelControllable, _ heightTracking: HeightTracking) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
    self.leftPanel = TreePanel(app, conLeft, heightTracking)
    self.rightPanel = TreePanel(app, conRight, heightTracking)
    self.heightTracking = heightTracking
  }

  var body: some View {
    LazyVGrid(
      columns: columns,
      alignment: .leading,
      spacing: 0  // no vertical spacing between cells
    ) {
      // Row0: Root Path
      self.leftPanel.rootPathPanel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Root", col: 0, height: geo.size.height))
        })
      self.rightPanel.rootPathPanel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Root", col: 1, height: geo.size.height))
        })

      // Row1: filter panel
      self.leftPanel.filterPanel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Filter", col: 0, height: geo.size.height))
        })
      self.rightPanel.filterPanel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Filter", col: 1, height: geo.size.height))
        })

      // Row2: Tree view
      self.leftPanel.treeView
      self.rightPanel.treeView

      // Row3: Status msg
      self.leftPanel.status_panel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Status", col: 0, height: geo.size.height))
        })
      self.rightPanel.status_panel
        .background(GeometryReader { geo in
          Color.clear
            .preference(key: MyHeightPreferenceKey.self, value: MyHeightPreferenceData(name: "Status", col: 1, height: geo.size.height))
        })

      // Row4: Button bar & progress bar
      ButtonBar(app: self.app, conLeft: self.conLeft, conRight: self.conRight)
        .environmentObject(settings)
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
        let height1 = key.col1[name]!
        totalHeight += max(height0, height1)
      }
//      NSLog("SIZES: \(key.col0), \(key.col1)")
//      NSLog("TOTAL HEIGHT: \(totalHeight) (subtract from \(settings.mainWindowHeight))")
      self.heightTracking.nonTreeViewHeight = totalHeight
    }
  }
}
