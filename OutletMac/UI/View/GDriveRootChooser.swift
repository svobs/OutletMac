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
 The content area of the Google Drive root chooser.
 */
struct GDriveRootChooserContent: View {
  @StateObject var heightTracking: HeightTracking = HeightTracking()
  var parentWindow: NSWindow
  let app: OutletApp
  let con: TreePanelControllable
  let targetTreeID: String
  @ObservedObject var chooserState: ChooserState

  init(_ app: OutletApp, _ con: TreePanelControllable, _ targetTreeID: String, _ parentWindow: NSWindow, _ chooserState: ChooserState) {
    self.parentWindow = parentWindow
    self.app = app
    self.con = con
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

    guard let node = selectedSN.node else {
      return
    }

    guard node.isDir else {
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
        SinglePaneView(self.app, self.con, self.heightTracking)
          .environmentObject(self.app.settings)
          .frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .topLeading)
          .contentShape(Rectangle()) // taps should be detected in the whole window
          .preference(key: ContentAreaPrefKey.self, value: ContentAreaPrefData(height: geo.size.height))
        .onPreferenceChange(ContentAreaPrefKey.self) { key in
  //        NSLog("HEIGHT OF WINDOW CANVAS: \(key.height)")
          self.heightTracking.mainWindowHeight = key.height
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

/**
 Container class for all GDrive root chooser dialog data. Actual view starts with GDriveRootChooserContent
 */
class GDriveRootChooser: PopUpTreePanel {
  var chooserState: ChooserState = ChooserState()

  init(_ app: OutletApp, _ con: TreePanelControllable, initialSelection: SPIDNodePair, targetTreeID: TreeID) {
    super.init(app, con, initialSelection: initialSelection)
    assert(con.treeID == ID_GDRIVE_DIR_SELECT)
    self.window.center()
    self.window.title = "Google Drive Root Chooser"
    // this will override the content rect and save the window size & location between launches, BUT it is also very buggy!
//    window.setFrameAutosaveName(window.title)
    let content = GDriveRootChooserContent(self.app, self.con, targetTreeID, self.window, self.chooserState)
    window.contentView = NSHostingView(rootView: content)
  }

  // DispatchListener callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  override func onSelectionChanged(_ senderID: SenderID, _ props: PropDict) throws {
    let snList: [SPIDNodePair] = try props.getArray("sn_list") as! [SPIDNodePair]
    assert(snList.count <= 1)

    DispatchQueue.main.async {
      let selectionValid = (snList.count == 1 && snList[0].node!.isDir)
      self.chooserState.selectionIsValid = selectionValid
      NSLog("DEBUG [\(self.con.treeID)] Selection changed: valid=\(self.chooserState.selectionIsValid) (\(snList.count == 1 && snList[0].node!.isDir))")
    }
  }

}
