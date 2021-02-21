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
    } .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

}

/**
 STRUCT TreeViewPanel
 */
struct TreeViewPanel: View {
  
  var outlineTree: OutlineTree<ExampleClass, [ExampleClass]>
  @State var selectedItem: OutlineNode<ExampleClass>? = nil
  
  init(items: [ExampleClass]) {
    outlineTree = OutlineTree(representedObjects: items)
  }
  
  var body: some View {
    OutlineSection<ExampleClass, [ExampleClass]>(selectedItem: $selectedItem).environmentObject(outlineTree)
      .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
  }
}

struct LegacyOutlineViewWrapper: View {
  let con: TreeControllable

  init(controller: TreeControllable) {
    self.con = controller
  }

  var body: some View {
    HStack {
      TreeViewRepresentable(controller: self.con)
        .padding(.top)
        .frame(height: 200.0)
        .frame(alignment: .topLeading)
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
  let root_dir_panel: RootDirPanel
  let filter_panel: FilterPanel
  let tree_view: LegacyOutlineViewWrapper
  let status_panel: StatusPanel

  init(controller: TreeControllable) {
    self.con = controller
    self.root_dir_panel = RootDirPanel(controller: self.con, canChangeRoot: true)
    self.filter_panel = FilterPanel(controller: self.con)
    self.tree_view = LegacyOutlineViewWrapper(controller: self.con)
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
        RegularImage(imageName: "pause.fill", width: width, height: height)
      } else {
        InvertedWhiteCircleImage(imageName: "play.fill", width: width, height: height)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

/**
 STRUCT ButtonBar
 */
fileprivate struct ButtonBar: View {
  @EnvironmentObject var settings: GlobalSettings
  let conLeft: TreeControllable
  let conRight: TreeControllable

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
    NSLog("Diff btn clicked! Sending request to BE to diff trees '\(self.conLeft.treeID)' & '\(self.conRight.treeID)'")

    // First disable UI
    self.conLeft.dispatcher.sendSignal(signal: .TOGGLE_UI_ENABLEMENT, senderID: ID_MAIN_WINDOW, ["enable": true])

    // Now ask BE to start the diff
    do {
      _ = try self.conLeft.backend.startDiffTrees(treeIDLeft: self.conLeft.treeID, treeIDRight: self.conRight.treeID)
      // We will be notified asynchronously when it is done/failed. If successful, the old tree_ids will be notified and supplied the new IDs
    } catch {
      NSLog("ERROR Failed to start tree diff: \(error)")
    }
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
    GridItem(.flexible(minimum: 300), spacing: H_PAD),
    GridItem(.flexible(minimum: 300), spacing: H_PAD),
  ]

  let app: OutletApp
  let conLeft: TreeControllable
  let conRight: TreeControllable
  let left_tree_panel: TreePanel
  let right_tree_panel: TreePanel

  init(app: OutletApp, conLeft: TreeControllable, conRight: TreeControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
    self.left_tree_panel = TreePanel(controller: conLeft)
    self.right_tree_panel = TreePanel(controller: conRight)
  }

  private var symbols = ["keyboard", "hifispeaker.fill", "printer.fill", "tv.fill", "desktopcomputer", "headphones", "tv.music.note", "mic", "plus.bubble", "video"]
  private var colors: [Color] = [.yellow, .purple, .green]


  var body: some View {
    //        ScrollView(.vertical) {
    LazyVGrid(
      columns: columns,
      alignment: .center,
      spacing: V_PAD
      //                pinnedViews: [.sectionHeaders, .sectionFooters]
    ) {
      //                ForEach((0...10), id: \.self) {
      //                    Image(systemName: symbols[$0 % symbols.count])
      //                        .font(.system(size: 30))
      //                        .frame(width: 50, height: 50)
      //                        .background(colors[$0 % colors.count])
      //                        .cornerRadius(10)
      //                }
      self.left_tree_panel.root_dir_panel
      self.right_tree_panel.root_dir_panel

      self.left_tree_panel.filter_panel
      self.right_tree_panel.filter_panel

      self.left_tree_panel.tree_view
      self.right_tree_panel.tree_view


      self.left_tree_panel.status_panel
      self.right_tree_panel.status_panel

      // Button Bar
      ButtonBar(conLeft: self.conLeft, conRight: self.conRight)

      TodoPlaceholder("<PROGRESS BAR>")

      //                Section(header: Text("Section 1").font(.title)) {
      //                    self.leftItemList.forEach {
      //                        Rectangle().fill(Color.green)
      //                        print($0)
      //                    }
      //                }
    }.frame(width: 800, height: 500)
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
