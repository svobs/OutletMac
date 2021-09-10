//
//  MainContentView.swift
//
//  Created by Matthew Svoboda on 1/6/21.
//
import SwiftUI

/**
 Has two panes (Left and Right), each of which contain a TreeView and its associated panels
 */
class MainWindow: AppWindow, ObservableObject {
  private weak var conLeft: TreePanelControllable!
  private weak var conRight: TreePanelControllable!
  private var contentRect = NSRect(x: DEFAULT_MAIN_WIN_X, y: DEFAULT_MAIN_WIN_Y, width: DEFAULT_MAIN_WIN_WIDTH, height: DEFAULT_MAIN_WIN_HEIGHT)
  private lazy var winCoordsTimer = HoldOffTimer(WIN_SIZE_STORE_DELAY_MS, self.reportWinCoords)

  private var isShutdownAppOnClose: Bool = true

  override var winID: String {
    get {
      ID_MAIN_WINDOW
    }
  }

  init(_ app: OutletApp, _ contentRect: NSRect? = nil, conLeft: TreePanelControllable, conRight: TreePanelControllable) {
    if let customContentRect = contentRect {
      self.contentRect = customContentRect
    }

    self.conLeft = conLeft
    self.conRight = conRight

    let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    super.init(app, self.contentRect, styleMask: style)
    self.isReleasedWhenClosed = false  // i.e., don't crash when re-opening
    self.title = "OutletMac"

    let contentView = MainContentView(app: app, conLeft: self.conLeft, conRight: self.conRight)
            .environmentObject(self.app.globalState)
    self.contentView = NSHostingView(rootView: contentView)
  }

  override func start() throws {
    try super.start()  // this creates the dispatchListener

    // These are close to being global, but , we listen for these here rather than in OutletApp
    // mainly because we want to discard these signals if this window is not open
    dispatchListener.subscribe(signal: .DIFF_TREES_DONE, afterDiffTreesDone)
    dispatchListener.subscribe(signal: .DIFF_TREES_FAILED, afterDiffTreesFailed)
    dispatchListener.subscribe(signal: .DIFF_TREES_CANCELLED, afterDiffExited)
    dispatchListener.subscribe(signal: .GENERATE_MERGE_TREE_DONE, afterMergeTreeGenerated)
    dispatchListener.subscribe(signal: .GENERATE_MERGE_TREE_FAILED, afterGenMergeTreeFailed)
    dispatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, onEnableUIToggled)

    // Request these AFTER we start listening for a response:
    try self.conLeft.requestTreeLoad()  // async
    try self.conRight.requestTreeLoad()  // async
  }

  /**
   This is called by the pre-close() listener
   */
  override func shutdown() throws {
    try super.shutdown()  // disconnects listeners

    self.app.execAsync {
      do {
        try self.conLeft?.shutdown()
        try self.conRight?.shutdown()
      } catch {
        NSLog("ERROR [\(self.winID)] Failed to shut down tree controllers: \(error)")
      }

      if self.isShutdownAppOnClose {
        NSLog("INFO  [\(self.winID)] Window closed by user: shutting down app")
        do {
          try self.app.shutdown()
        } catch {
          NSLog("ERROR [\(self.winID)] Failure during app shutdown: \(error)")
        }
      } else {
        // closed by program, not user
        NSLog("DEBUG [\(self.winID)] Closing window without shutting down")
      }
    }
  }

  func closeWithoutAppShutdown() {
    self.isShutdownAppOnClose = false
    defer {
      self.isShutdownAppOnClose = true
    }
    // See: windowWillClose() method below
    self.close()
  }

  // SignalDispatcher callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func afterDiffTreesDone(senderID: SenderID, propDict: PropDict) throws {
    let leftTree = try propDict.get("tree_left") as! DisplayTree
    let rightTree = try propDict.get("tree_right") as! DisplayTree
    try self.conLeft.updateDisplayTree(to: leftTree)
    try self.conRight.updateDisplayTree(to: rightTree)
    // This will change the button bar:
    self.changeWindowMode(.DIFF)
    self.app.sendEnableUISignal(enable: true)
  }

  private func afterDiffTreesFailed(senderID: SenderID, propDict: PropDict) throws {
    // Change button bar back:
    self.changeWindowMode(.BROWSING)
    self.app.sendEnableUISignal(enable: true)
  }

  private func afterDiffExited(senderID: SenderID, propDict: PropDict) throws {
    let leftTree = try propDict.get("tree_left") as! DisplayTree
    let rightTree = try propDict.get("tree_right") as! DisplayTree
    try self.conLeft.updateDisplayTree(to: leftTree)
    try self.conRight.updateDisplayTree(to: rightTree)

    // This will change the button bar:
    self.changeWindowMode(.BROWSING)
    self.app.sendEnableUISignal(enable: true)
  }

  private func afterMergeTreeGenerated(senderID: SenderID, propDict: PropDict) throws {
    NSLog("DEBUG [\(self.winID)] Got signal: \(Signal.GENERATE_MERGE_TREE_DONE)")
    let newTree = try propDict.get("tree") as! DisplayTree
    // Need to execute in a different queue, 'cuz buildController() makes a gRPC call, and we can't do that in a thread which came from gRPC
    do {
      // This will put the controller in the registry as a side effect
      let _ = try self.app.buildController(newTree, canChangeRoot: false, allowsMultipleSelection: false)
      // note: we can't send a controller directly to this method (cuz of @objc), so instead we put it in our controller registry and later look it up.
      NSApp.sendAction(#selector(OutletMacApp.openMergePreview), to: nil, from: newTree.treeID)
    } catch {
      self.app.displayError("Failed to build merge tree", "\(error)")
    }
  }

  private func afterGenMergeTreeFailed(senderID: SenderID, propDict: PropDict) throws {
    // Re-enable UI:
    self.app.sendEnableUISignal(enable: true)
  }

  private func onEnableUIToggled(_ senderID: SenderID, _ propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("enable")
    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.winID)] Setting isUIEnabled to: \(isEnabled)")
      self.app.globalState.isUIEnabled = isEnabled
    }
  }

  private func changeWindowMode(_ newMode: WindowMode) {
    DispatchQueue.main.async {
      NSLog("DEBUG [\(self.winID)] Setting WindowMode to: \(newMode)")
      self.app.globalState.mode = newMode
    }
  }

  // NSWindowDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  @objc func windowDidResize(_ notification: Notification) {
    if TRACE_ENABLED {
      NSLog("DEBUG [\(self.winID)] Window resized! \(self.frame.size as Any)")
    }
    self.contentRect = self.frame
    self.winCoordsTimer.reschedule()
  }

  @objc func windowDidMove(_ notification: Notification) {
    if TRACE_ENABLED {
      NSLog("DEBUG [\(self.winID)] Window moved! \(self.frame.origin as Any)")
    }
    self.contentRect = self.frame
    self.winCoordsTimer.reschedule()
  }

//  @objc func windowDidChangeScreen(_ notification: Notification) {
//    NSLog("WINDOW CHANGED SCREEN!!!!!")
//  }

  // Other
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Fired by HoldOffTimer
   */
  private func reportWinCoords() {
    let rect = self.contentRect
    NSLog("DEBUG [\(self.winID)] Firing timer to report mainWindow size: \(rect)")

    var configDict = [String: String]()
    configDict["ui_state.\(winID).x"] = String(Int(rect.minX))
    configDict["ui_state.\(winID).y"] = String(Int(rect.minY))
    configDict["ui_state.\(winID).width"] = String(Int(rect.width))
    configDict["ui_state.\(winID).height"] = String(Int(rect.height))

    do {
      try self.app.backend.putConfigList(configDict)
    } catch {
      NSLog("ERROR [\(self.winID)] Failed to report mainWindow size: \(error)")
      return
    }
  }
}

/**
 MainWindow's main view
 */
struct MainContentView: View {
  @EnvironmentObject var globalState: GlobalState
  @StateObject var windowState: WindowState = WindowState()
  weak var app: OutletApp!
  weak var conLeft: TreePanelControllable!
  weak var conRight: TreePanelControllable!
  @State private var window: NSWindow?  // enclosing window(?)

  init(app: OutletApp, conLeft: TreePanelControllable, conRight: TreePanelControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
  }

  func dismissAlert() {
     DispatchQueue.main.async {
       self.globalState.dismissAlert()
     }
  }

  var body: some View {
    let tapCancelEdit = TapGesture()
      .onEnded { _ in
        NSLog("DEBUG [\(ID_MAIN_WINDOW)] Tapped!")
        app.dispatcher.sendSignal(signal: .CANCEL_ALL_EDIT_ROOT, senderID: ID_MAIN_WINDOW)
      }

    // Here, I use GeometryReader to get the full canvas size (sans window decoration)
    GeometryReader { geo in
      TwoPaneView(app: self.app, conLeft: self.conLeft, conRight: self.conRight, windowState)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle()) // taps should be detected in the whole window
        .gesture(tapCancelEdit)
        .alert(isPresented: $globalState.showingAlert) {
          Alert(title: Text(globalState.alertTitle),
                message: Text(globalState.alertMsg),
                dismissButton: .default(Text(globalState.dismissButtonText), action: self.dismissAlert))
        }
        .preference(key: ContentAreaPrefKey.self, value: ContentAreaPrefData(height: geo.size.height))
      .onPreferenceChange(ContentAreaPrefKey.self) { key in
        if TRACE_ENABLED {
          NSLog("DEBUG [\(ID_MAIN_WINDOW)] HEIGHT OF WINDOW CANVAS: \(key.height)")
        }
        self.windowState.windowHeight = key.height
      }
    }
  }
}
