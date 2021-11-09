//
//  GDrivePathSelectionDialog.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/20.
//

import SwiftUI

/**
 Wrap the selection in an ObservableObject so objects outside of the view can alter the view...
 What a headache.
 */
class ChooserState: ObservableObject {
  @Published var selectionIsValid: Bool = false
}

/**
 Container class for all GDrive root chooser dialog data. Actual view starts with GDriveRootChooserContent
 */
class GDriveRootChooserWindow: SingleTreePopUpWindow {
  var chooserState: ChooserState = ChooserState()
  let targetTreeID: TreeID

  init(_ app: OutletApp, _ treeID: TreeID, targetTreeID: TreeID) {
    self.targetTreeID = targetTreeID
    assert(treeID == ID_GDRIVE_DIR_SELECT)
    super.init(app, treeID: treeID)
    self.center()
    self.isReleasedWhenClosed = false  // make it reusable
    self.title = "Google Drive Root Chooser"
    // this will override the content rect and save the window size & location between launches, BUT it is also very buggy!
//    window.setFrameAutosaveName(window.title)
  }

  override func setController(_ con: TreePanelControllable, initialSelection: SPIDNodePair?) {
    super.setController(con, initialSelection: initialSelection)
    let content = GDriveRootChooserContent(targetTreeID, self, self.chooserState)
            .environmentObject(self.app.globalState)
    self.contentView = NSHostingView(rootView: content)
  }

  // DispatchListener callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  override func onSelectionChanged(_ senderID: SenderID, _ props: PropDict) throws {
    let snList: [SPIDNodePair] = try props.getArray("sn_list") as! [SPIDNodePair]
    assert(snList.count <= 1)

    DispatchQueue.main.async {
      let selectionValid = (snList.count == 1 && snList[0].node.isDir)
      self.chooserState.selectionIsValid = selectionValid
      NSLog("DEBUG [\(self.winID)] Selection changed: valid=\(self.chooserState.selectionIsValid) (\(snList.count == 1 && snList[0].node.isDir))")
    }
  }

/**
 The content area of the Google Drive root chooser.
 */
struct GDriveRootChooserContent: View {
  @StateObject var windowState: WindowState = WindowState()
  var parentWindow: GDriveRootChooserWindow
  let targetTreeID: String
  @ObservedObject var chooserState: ChooserState

  var con: TreePanelControllable {
    get {
      return self.parentWindow.con!
    }
  }

  init(_ targetTreeID: String, _ parentWindow: GDriveRootChooserWindow, _ chooserState: ChooserState) {
    self.parentWindow = parentWindow
    self.targetTreeID = targetTreeID
    self.chooserState = chooserState
  }

  func chooseItem() {
    guard let selectedGUIDs = self.con.treeView?.getSelectedGUIDs() else {
      return
    }
    guard selectedGUIDs.count == 1 else {
      return
    }
    guard let selectedGUID = selectedGUIDs.first else {
      return
    }
    guard let selectedSN = self.con.displayStore.getSN(selectedGUID) else {
      return
    }

    guard selectedSN.node.isDir else {
      // Should not happen. But just to be careful
      NSLog("ERROR [\(self.con.treeID)] Not a directory: \(selectedSN.spid)")
      return
    }

    NSLog("DEBUG [\(self.con.treeID)] User chose \(selectedSN.spid)")
    do {
      let _ = try self.con.app.backend.createDisplayTreeFromSPID(treeID: self.targetTreeID, spid: selectedSN.spid)
    } catch {
      self.con.reportException("Failed to select item", error)
    }

    self.parentWindow.close()
  }

  var body: some View {
    VStack {
      GeometryReader { geo in
        SinglePaneView(self.parentWindow.app, self.con, self.windowState)
          .frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .topLeading)
          .contentShape(Rectangle()) // taps should be detected in the whole window
          .preference(key: ContentAreaPrefKey.self, value: ContentAreaPrefData(height: geo.size.height))
        .onPreferenceChange(ContentAreaPrefKey.self) { key in
  //        NSLog("HEIGHT OF WINDOW CANVAS: \(key.height)")
          self.windowState.windowHeight = key.height
        }
      }
      HStack {
        Spacer()
        Button("Cancel", action: {self.parentWindow.close()})
          .keyboardShortcut(.cancelAction)
        Button("Select", action: self.chooseItem)
          .keyboardShortcut(.defaultAction)  // this will also color the button
          .disabled(!self.chooserState.selectionIsValid)
      }
      .padding(.bottom).padding(.horizontal)  // we have enough padding above already
    }.frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)  // set minimum window dimensions
  }

}

}
