//
//  MainContentView.swift
//
//  Created by Matthew Svoboda on 1/6/21.
//
import SwiftUI

let SHOW_TOOLBAR_ON_START = true

/**
 Has two panes (Left and Right), each of which contain a TreeView and its associated panels
 */
class MainWindow: AppWindow, ObservableObject {
  private weak var conLeft: TreePanelControllable? = nil
  private weak var conRight: TreePanelControllable? = nil
  private var contentRect = NSRect(x: DEFAULT_MAIN_WIN_X, y: DEFAULT_MAIN_WIN_Y, width: DEFAULT_MAIN_WIN_WIDTH, height: DEFAULT_MAIN_WIN_HEIGHT)
  private lazy var winCoordsTimer = HoldOffTimer(WIN_SIZE_STORE_DELAY_MS, self.reportWinCoords)

  private var isShutdownAppOnClose: Bool = true

  override var winID: String {
    get {
      ID_MAIN_WINDOW
    }
  }

  init(_ app: OutletApp, _ contentRect: NSRect? = nil) {
    if let customContentRect = contentRect {
      self.contentRect = customContentRect
    }

    let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    super.init(app, self.contentRect, styleMask: style)
    self.isReleasedWhenClosed = false  // i.e., don't crash when re-opening
    self.title = "OutletMac"
    self.toolbar = MainWindowToolbar(identifier: .init("Default"))
    if !SHOW_TOOLBAR_ON_START {
      self.toggleToolbarShown(self)
    }
  }

  func setControllers(left: TreePanelControllable, right: TreePanelControllable) {
    self.conLeft = left
    self.conRight = right

    let contentView = MainContentView(app: app, conLeft: left, conRight: right)
            .environmentObject(self.app.globalState)
    self.contentView = NSHostingView(rootView: contentView)
  }

  override func start() throws {
    guard let left = self.conLeft, let right = self.conRight else {
      throw OutletError.invalidState("Controllers not set!")
    }

    try super.start()  // this creates the dispatchListener

    // These are close to being global, but , we listen for these here rather than in OutletApp
    // mainly because we want to discard these signals if this window is not open
    dispatchListener.subscribe(signal: .DIFF_TREES_DONE, afterDiffTreesDone)
    dispatchListener.subscribe(signal: .DIFF_TREES_FAILED, afterDiffTreesFailed)
    dispatchListener.subscribe(signal: .DIFF_TREES_CANCELLED, afterDiffExited)
    dispatchListener.subscribe(signal: .GENERATE_MERGE_TREE_FAILED, afterGenMergeTreeFailed)
    dispatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, onEnableUIToggled)

    // Request these AFTER we start listening for a response:
    try left.requestTreeLoad()  // async
    try right.requestTreeLoad()  // async
    NSLog("DEBUG [\(self.winID)] Start done")
  }

  /**
   This is called by the pre-close() listener
   */
  override func shutdown() throws {
    try super.shutdown()  // disconnects listeners

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
    guard let left = self.conLeft, let right = self.conRight else {
      NSLog("WARN  [\(self.winID)] Controllers not set: ignoring signal \(Signal.DIFF_TREES_DONE)")
      return
    }
    let leftTree = try propDict.get("tree_left") as! DisplayTree
    let rightTree = try propDict.get("tree_right") as! DisplayTree
    try left.updateDisplayTree(to: leftTree)
    try right.updateDisplayTree(to: rightTree)
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
    guard let left = self.conLeft, let right = self.conRight else {
      NSLog("WARN  [\(self.winID)] Controllers not set: ignoring signal \(Signal.DIFF_TREES_CANCELLED)")
      return
    }
    let leftTree = try propDict.get("tree_left") as! DisplayTree
    let rightTree = try propDict.get("tree_right") as! DisplayTree
    try left.updateDisplayTree(to: leftTree)
    try right.updateDisplayTree(to: rightTree)

    // This will change the button bar:
    self.changeWindowMode(.BROWSING)
    self.app.sendEnableUISignal(enable: true)
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
        NSLog("DEBUG [\(ID_MAIN_WINDOW)] User tapped!")
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
