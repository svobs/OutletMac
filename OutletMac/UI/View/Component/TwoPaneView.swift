//
//  TwoPaneView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 1/6/21.
//  Copyright © 2021 Ibotta. All rights reserved.
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
 STRUCT TreePanel

 Just a container for all the components for a given tree
 */
struct TreePanel {
  let con: TreeControllable
  let rootPathPanel: RootPathPanel
  let filterPanel: FilterPanel
  let treeView: TreeView
  let status_panel: StatusPanel

  init(controller: TreeControllable) {
    self.con = controller
    self.rootPathPanel = RootPathPanel(controller: self.con, canChangeRoot: true)
    self.filterPanel = FilterPanel(controller: self.con)
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

/**
 TODO: refactor to share code with BoolToggleButton, TernaryToggleButton
 */
struct PlayPauseToggleButton: View {
  @Binding var isPlaying: Bool
  let dispatcher: SignalDispatcher
  let width: CGFloat = DEFAULT_TERNARY_BTN_WIDTH
  let height: CGFloat = DEFAULT_TERNARY_BTN_HEIGHT
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ isPlaying: Binding<Bool>, _ dispatcher: SignalDispatcher) {
   self._isPlaying = isPlaying
   self.dispatcher = dispatcher
   self.onClickAction = onClickAction == nil ? self.toggleValue : onClickAction!
 }

  private func toggleValue() {
    if self.isPlaying {
      NSLog("Play/Pause btn clicked! Sending signal \(Signal.PAUSE_OP_EXECUTION)")
      dispatcher.sendSignal(signal: .PAUSE_OP_EXECUTION, senderID: ID_MAIN_WINDOW)
    } else {
      NSLog("Play/Pause btn clicked! Sending signal \(Signal.RESUME_OP_EXECUTION)")
      dispatcher.sendSignal(signal: .RESUME_OP_EXECUTION, senderID: ID_MAIN_WINDOW)
    }
  }

  var body: some View {
    Button(action: onClickAction!) {
      if isPlaying {
        RegularImage(systemImageName: "pause.fill", width: width, height: height, font: BUTTON_PANEL_FONT)
      } else {
        InvertedWhiteCircleImage(systemImageName: "play.fill", width: width, height: height, font: BUTTON_PANEL_FONT)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// TODO: from https://troz.net/post/2019/swiftui-for-mac-2/
struct PrefsView: View {
  @State var prefsWindowDelegate = PrefsWindowDelegate()

  var body: some View {
    Text("Hello, Prefs!")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  var window: NSWindow!
  init() {
    window = NSWindow()
    window.title = "Preferences"
    // note: x & y are from lower-left corner
    window.setFrame(NSRect(x: 200, y: 200, width: 400, height: 200), display: true)
    window.contentView = NSHostingView(rootView: self)
    window.delegate = prefsWindowDelegate
    prefsWindowDelegate.windowIsOpen = true
    window.makeKeyAndOrderFront(nil)
  }

  class PrefsWindowDelegate: NSObject, NSWindowDelegate {
    var windowIsOpen = false

    func windowWillClose(_ notification: Notification) {
      windowIsOpen = false
    }
  }
}

/**
 STRUCT ButtonBar
 */
fileprivate struct ButtonBar: View {
  @EnvironmentObject var settings: GlobalSettings
  let conLeft: TreeControllable
  let conRight: TreeControllable

  var prefsView: PrefsView?

  init(conLeft: TreeControllable, conRight: TreeControllable) {
    self.conLeft = conLeft
    self.conRight = conRight
  }

  var body: some View {
    HStack {
      Button("Diff (content-first)", action: self.onDiffButtonClicked)
      Button("Download Google Drive meta", action: self.onDownloadFromGDriveButtonClicked)
      PlayPauseToggleButton($settings.isPlaying, conLeft.dispatcher)
      Spacer()
    }
    .padding(.leading, H_PAD)
    .buttonStyle(BorderedButtonStyle())
  }

  // UI callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func onDiffButtonClicked() {
//    if let prefsView = prefsView, prefsView.prefsWindowDelegate.windowIsOpen {
//      prefsView.window.makeKeyAndOrderFront(self)
//    } else {
//      prefsView = PrefsView()
//    }
//    _ = PrefsView()

    NSApp.sendAction(#selector(OutletMacApp.openPreferencesWindow), to: nil, from:nil)

    /*
    NSLog("Diff btn clicked! Sending request to BE to diff trees '\(self.conLeft.treeID)' & '\(self.conRight.treeID)'")

    // First disable UI
    self.conLeft.dispatcher.sendSignal(signal: .TOGGLE_UI_ENABLEMENT, senderID: ID_MAIN_WINDOW, ["enable": true])

    // Now ask BE to start the diff
    do {
      _ = try self.conLeft.backend.startDiffTrees(treeIDLeft: self.conLeft.treeID, treeIDRight: self.conRight.treeID)
      // We will be notified asynchronously when it is done/failed. If successful, the old tree_ids will be notified and supplied the new IDs
    } catch {
      NSLog("ERROR Failed to start tree diff: \(error)")
    }*/
  }

  func onDownloadFromGDriveButtonClicked() {
    NSLog("DownloadGDrive btn clicked! Sending signal: '\(Signal.DOWNLOAD_ALL_GDRIVE_META)'")
    self.conLeft.dispatcher.sendSignal(signal: .DOWNLOAD_ALL_GDRIVE_META, senderID: ID_MAIN_WINDOW)
  }
}

/**
 STRUCT TwoPaneView
 */
struct TwoPaneView: View {
  @EnvironmentObject var settings: GlobalSettings

  private var columns: [GridItem] = [
    // these specify spacing between columns
    // note: min width must be set here, so that toolbars don't get squished
    GridItem(.flexible(minimum: 400, maximum: .infinity), spacing: H_PAD),
    GridItem(.flexible(minimum: 400, maximum: .infinity), spacing: H_PAD),
  ]

  let app: OutletApp
  let conLeft: TreeControllable
  let conRight: TreeControllable
  let leftPanel: TreePanel
  let rightPanel: TreePanel

  init(app: OutletApp, conLeft: TreeControllable, conRight: TreeControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
    self.leftPanel = TreePanel(controller: conLeft)
    self.rightPanel = TreePanel(controller: conRight)
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
      ButtonBar(conLeft: self.conLeft, conRight: self.conRight)
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
      self.settings.nonTreeViewHeight = totalHeight
    }
  }
}

struct TwoPaneView_Previews: PreviewProvider {
  static let conLeft = MockTreeController(ID_LEFT_TREE)
  static let conRight = MockTreeController(ID_RIGHT_TREE)
  static var previews: some View {
    TwoPaneView(app: MockApp(), conLeft: conLeft, conRight: conRight)
      .colorScheme(.dark)
      .environmentObject(GlobalSettings())
  }
}
