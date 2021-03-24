//
//  GDrivePathSelectionDialog.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/20.
//

import SwiftUI

class GDriveRootChooserDelegate: NSObject, NSWindowDelegate {
  var windowIsOpen = true
  var parentMeta: GDriveRootChooser? = nil

  func windowWillClose(_ notification: Notification) {
    windowIsOpen = false

    if let parent = parentMeta {
      do {
        try parent.shutdown()
      } catch {
        NSLog("ERROR Failure during GDrive root chooser shutdown; \(error)")
      }
    }
  }
}

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
  let con: TreeControllable
  let targetTreeID: String
  @ObservedObject var chooserState: ChooserState

  init(_ app: OutletApp, _ con: TreeControllable, _ targetTreeID: String, _ parentWindow: NSWindow, _ chooserState: ChooserState) {
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
    }.frame(minWidth: 400, maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, minHeight: 400, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)  // set minimum window dimensions
  }

}

/**
 Container class for all GDrive root chooser dialog data. Actual view starts with GDriveRootChooserContent
 */
class GDriveRootChooser: HasLifecycle, ObservableObject {
  var window: NSWindow!
  @State var windowDelegate = GDriveRootChooserDelegate()
  var chooserState: ChooserState = ChooserState()
  let initialSelection: SPIDNodePair

  let app: OutletApp
  let con: TreeControllable
  let dispatchListener: DispatchListener
  private var loadComplete: Bool = false

  var isOpen: Bool {
    get {
      return windowDelegate.windowIsOpen
    }
  }

  init(_ app: OutletApp, _ con: TreeControllable, targetTreeID: String, initialSelection: SPIDNodePair) {
    self.app = app
    self.con = con
    self.initialSelection = initialSelection
    self.dispatchListener = self.app.dispatcher.createListener("\(self.con.treeID))-dialog")
    assert(con.treeID == ID_GDRIVE_DIR_SELECT)
    // TODO: save content rect in config
    // note: x & y are from lower-left corner
    let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
    window = NSWindow(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    // this will override x & y from content rect
    window.center()
    window.title = "Google Drive Root Chooser"
    // this will override the content rect and save the window size & location between launches, BUT it is also very buggy!
//    window.setFrameAutosaveName(window.title)
    let content = GDriveRootChooserContent(self.app, self.con, targetTreeID, self.window, self.chooserState)
    window.delegate = self.windowDelegate
    window.contentView = NSHostingView(rootView: content)
//    window.setDefaultButtonCell(
  }

  func start() throws {
    self.windowDelegate.parentMeta = self

//    try self.dispatchListener.subscribe(signal: .TREE_SELECTION_CHANGED, self.onSelectionChanged) // TODO
    try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_DONE, self.onBackendReady, whitelistSenderID: self.con.treeID)
    try self.dispatchListener.subscribe(signal: .POPULATE_UI_TREE_DONE, self.onPopulateComplete, whitelistSenderID: self.con.treeID)

    try self.dispatchListener.subscribe(signal: .TREE_SELECTION_CHANGED, self.onSelectionChanged, whitelistSenderID: self.con.treeID)

    // TODO: create & populate progress bar to show user that something is being done here

    try self.con.loadTree()
  }

  func shutdown() throws {
    try self.dispatchListener.unsubscribeAll()
  }

  func moveToFront() {
    if loadComplete {
      DispatchQueue.main.async {
        self.window.makeKeyAndOrderFront(nil)
      }
    }
  }

  func selectSPID(_ spid: SPID) {
    // If successful, this should fire the selection listener, which will result in onSelectionChanged() below
    // being hit
    self.con.treeView!.selectSingleSPID(spid)
  }

  // DispatchListener callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func onBackendReady(_ senderID: SenderID, _ props: PropDict) throws {
    NSLog("DEBUG [\(self.con.treeID)] Backend load complete. Showing dialog")
    self.loadComplete = true
    self.moveToFront()
  }

  private func onPopulateComplete(_ senderID: SenderID, _ props: PropDict) throws {
    NSLog("DEBUG [\(self.con.treeID)] Populate complete! Selecting SPID: \(self.initialSelection.spid)")
    DispatchQueue.main.async {
      self.selectSPID(self.initialSelection.spid)
    }
  }

  private func onSelectionChanged(_ senderID: SenderID, _ props: PropDict) throws {
    let snList: [SPIDNodePair] = try props.getArray("sn_list") as! [SPIDNodePair]
    assert(snList.count <= 1)

    DispatchQueue.main.async {
      let selectionValid = (snList.count == 1 && snList[0].node!.isDir)
      self.chooserState.selectionIsValid = selectionValid
      NSLog("DEBUG [\(self.con.treeID)] Selection changed: selectionValid=\(self.chooserState.selectionIsValid) (\(snList.count == 1 && snList[0].node!.isDir))")
    }
  }

}
