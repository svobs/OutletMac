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

struct GDriveRootChooserContent: View {
  @StateObject var heightTracking: HeightTracking = HeightTracking()
  let app: OutletApp
  let con: TreeControllable
  let targetTreeID: String

  init(_ app: OutletApp, _ con: TreeControllable, _ targetTreeID: String) {
    self.app = app
    self.con = con
    self.targetTreeID = targetTreeID
  }

  var body: some View {
    GeometryReader { geo in
      SinglePaneView(self.app, self.con, self.heightTracking)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle()) // taps should be detected in the whole window
        .preference(key: ContentAreaPrefKey.self, value: ContentAreaPrefData(height: geo.size.height))
      .onPreferenceChange(ContentAreaPrefKey.self) { key in
//        NSLog("HEIGHT OF WINDOW CANVAS: \(key.height)")
        self.heightTracking.mainWindowHeight = key.height
      }
    }
  }

}

/**
 Container class for all GDrive root chooser dialog data. Actual view starts with GDriveRootChooserContent
 */
class GDriveRootChooser: HasLifecycle {
  var window: NSWindow!
  @State var windowDelegate = GDriveRootChooserDelegate()
  let content: GDriveRootChooserContent

  let app: OutletApp
  let con: TreeControllable
  let dispatchListener: DispatchListener
  let targetTreeID: String
  private var loadComplete: Bool = false

  var isOpen: Bool {
    get {
      return windowDelegate.windowIsOpen
    }
  }

  init(_ app: OutletApp, _ con: TreeControllable, targetTreeID: String) {
    self.app = app
    self.targetTreeID = targetTreeID
    self.con = con
    self.content = GDriveRootChooserContent(self.app, self.con, self.targetTreeID)
    self.dispatchListener = self.app.dispatcher.createListener("\(self.con.treeID))-dialog")
    assert(con.treeID == ID_GDRIVE_DIR_SELECT)
    window = NSWindow()
    window.title = "Google Drive Root Chooser"
    // note: x & y are from lower-left corner
    window.setFrame(NSRect(x: 200, y: 200, width: 400, height: 200), display: true)
    window.contentView = NSHostingView(rootView: self.content)
    window.delegate = windowDelegate
  }

  func start() throws {
    windowDelegate.parentMeta = self

//    try self.dispatchListener.subscribe(signal: .TREE_SELECTION_CHANGED, self.onSelectionChanged) // TODO
    try self.dispatchListener.subscribe(signal: .LOAD_SUBTREE_DONE, self.onBackendReady)
    try self.dispatchListener.subscribe(signal: .POPULATE_UI_TREE_DONE, self.onPopulateComplete)

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

  // DispatchListener callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func onBackendReady(_ senderID: SenderID, _ props: PropDict) throws {
    NSLog("DEBUG [\(self.con.treeID)] Backend load complete. Showing dialog")
    self.loadComplete = true
    self.moveToFront()
  }

  private func onPopulateComplete(_ senderID: SenderID, _ props: PropDict) throws {
    NSLog("DEBUG [\(self.con.treeID)] Populate complete! Sending signal \(Signal.EXPAND_AND_SELECT_NODE)")
    // TODO
//    dispatcher.send(Signal.EXPAND_AND_SELECT_NODE, sender=ID_GDRIVE_DIR_SELECT, spid=self._initial_selection_spid)
  }

}
