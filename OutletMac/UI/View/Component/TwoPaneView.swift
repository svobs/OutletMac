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

struct LegacyOutlineViewWrapper: View {
  let con: TreeControllable

  init(controller: TreeControllable) {
    self.con = controller
  }

  var body: some View {
    HStack {
      TreeView(controller: self.con)
        .padding(.top)
        .frame(minWidth: 200,
               maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               minHeight: 400, // FIXME: height should not be fixed at this value
               maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
               alignment: .topLeading)
  //      .onAppear(perform: retrievePlayers)
      Spacer()
    }
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
 STRUCT TreePanel
 */
struct TreePanel {
  let con: TreeControllable
  let rootPathPanel: RootPathPanel
  let filterPanel: FilterPanel
  let treeView: LegacyOutlineViewWrapper
  let status_panel: StatusPanel

  init(controller: TreeControllable) {
    self.con = controller
    self.rootPathPanel = RootPathPanel(controller: self.con, canChangeRoot: true)
    self.filterPanel = FilterPanel(controller: self.con)
    self.treeView = LegacyOutlineViewWrapper(controller: self.con)
    self.status_panel = StatusPanel(controller: self.con)
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
        RegularImage(systemImageName: "pause.fill", width: width, height: height)
      } else {
        InvertedWhiteCircleImage(systemImageName: "play.fill", width: width, height: height)
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
    _ = PrefsView()

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
  private var columns: [GridItem] = [
    // these specify spacing between columns
    GridItem(.flexible(minimum: 300, maximum: .infinity), spacing: H_PAD),
    GridItem(.flexible(minimum: 300, maximum: .infinity), spacing: H_PAD),
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
      spacing: V_PAD
    ) {
      self.leftPanel.rootPathPanel
      self.rightPanel.rootPathPanel

      self.leftPanel.filterPanel
      self.rightPanel.filterPanel

      self.leftPanel.treeView
      self.rightPanel.treeView


      self.leftPanel.status_panel
      self.rightPanel.status_panel

      // Button Bar
      ButtonBar(conLeft: self.conLeft, conRight: self.conRight)
        .frame(alignment: .bottomLeading)

      HStack {
        Spacer()
        TodoPlaceholder("<PROGRESS BAR>")
          .frame(alignment: .bottomTrailing)
      }
    }
    .frame(minWidth: 600,
           maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
           minHeight: 400,
           maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/,
           alignment: .topLeading)
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
