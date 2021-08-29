//
//  OutletApp.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 1/6/21.
//
import AppKit
import Cocoa
import SwiftUI

/**
 PROTOCOL OutletApp
 */
protocol OutletApp: HasLifecycle {
  var dispatcher: SignalDispatcher { get }
  var backend: OutletBackend { get }
  var iconStore: IconStore { get }

  var settings: GlobalSettings { get }

  func grpcDidGoDown()
  func grpcDidGoUp()

  func execAsync(_ workItem: @escaping NoArgVoidFunc)
  func execSync(_ workItem: @escaping NoArgVoidFunc)

  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool

  func registerTreePanelController(_ treeID: String, _ controller: TreePanelControllable)
  func deregisterTreePanelController(_ treeID: TreeID)
  func getTreePanelController(_ treeID: String) -> TreePanelControllable?

  func sendEnableUISignal(enable: Bool)

  func openGDriveRootChooser(_ deviceUID: UID, _ treeID: String)
}

// This is awesome: https://medium.com/@theboi/macos-apps-without-storyboard-or-xib-menu-bar-in-swift-5-menubar-and-toolbar-6f6f2fa39ccb
class AppMenu: NSMenu {
  override init(title: String) {
    super.init(title: title)

    let appMenu = NSMenuItem()
    appMenu.submenu = NSMenu()
    let appName = ProcessInfo.processInfo.processName
    appMenu.submenu?.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
    appMenu.submenu?.addItem(NSMenuItem.separator())
    let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
    services.submenu =  NSMenu()
    appMenu.submenu?.addItem(services)
    appMenu.submenu?.addItem(NSMenuItem.separator())
    appMenu.submenu?.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
    let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    appMenu.submenu?.addItem(hideOthers)
    appMenu.submenu?.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
    appMenu.submenu?.addItem(NSMenuItem.separator())
    appMenu.submenu?.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    items = [appMenu]
  }
  required init(coder: NSCoder) {
    super.init(coder: coder)
  }
}

class OutletMacApp: NSObject, NSApplicationDelegate, NSWindowDelegate, OutletApp {
  private var mainWindowIsOpen = false

  var rootChooserView: GDriveRootChooser!
  var mergePreviewView: MergePreview!
  var connectionProblemView: ConnectionProblemView!
  var mainWindow: NSWindow? = nil
  private var wasShutdown: Bool = false

  private var enableWindowCloseListener: Bool = true

  let winID = ID_MAIN_WINDOW
  let settings = GlobalSettings()
  let dispatcher = SignalDispatcher()
  let dispatchListener: DispatchListener!
  private var _backend: OutletGRPCClient?
  private var _iconStore: IconStore? = nil

  var conLeft: TreePanelController? = nil
  var conRight: TreePanelController? = nil
  let taskRunner: TaskRunner = TaskRunner()
  private var contentRect = NSRect(x: DEFAULT_MAIN_WIN_X, y: DEFAULT_MAIN_WIN_Y, width: DEFAULT_MAIN_WIN_WIDTH, height: DEFAULT_MAIN_WIN_HEIGHT)
  private lazy var winCoordsTimer = HoldOffTimer(WIN_SIZE_STORE_DELAY_MS, self.reportWinCoords)
  private var treeControllerDict: [String: TreePanelControllable] = [:]
  private let treeControllerLock = NSLock()

  var backend: OutletBackend {
    get {
      return self._backend!
    }
  }

  var iconStore: IconStore {
    get {
      return self._iconStore!
    }
  }

  override init() {
    dispatchListener = dispatcher.createListener(winID)
    super.init()
  }

  func start() throws {
    NSLog("DEBUG OutletMacApp start begin: '\(DispatchQueue.currentQueueLabel ?? "nil")'")

    var useFixedAddress: Bool = false
    var fixedHost: String? = nil
    var fixedPort: Int? = nil
    for (index, argument) in CommandLine.arguments.enumerated() {
      switch argument {
      case "--host":
        if CommandLine.arguments.count > index + 1 {
          useFixedAddress = true
          fixedHost = CommandLine.arguments[index + 1]
        } else {
          throw OutletError.invalidArgument("Option \"--host\" requires an argument.")
        }
      case "--port":
        if CommandLine.arguments.count > index + 1 {
          useFixedAddress = true
          if let port = Int(CommandLine.arguments[index + 1]) {
            fixedPort = port
          }
        } else {
          throw OutletError.invalidArgument("Option \"--port\" requires an argument.")
        }
      default:
        break
      }
    }

    if useFixedAddress {
      if fixedHost == nil {
        throw OutletError.invalidArgument("Option \"--host\" is required when \"--port\" is specified.")
      }
      if fixedPort == nil {
        throw OutletError.invalidArgument("Option \"--port\" not required when \"--host\" is specified.")
      }
    }

    self._backend = OutletGRPCClient(self, useFixedAddress: useFixedAddress, fixedHost: fixedHost, fixedPort: fixedPort)
    self._iconStore = IconStore(self.backend)

    // Subscribe to app-wide signals here
    dispatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, onEnableUIToggled)
    dispatchListener.subscribe(signal: .OP_EXECUTION_PLAY_STATE_CHANGED, onOpExecutionPlayStateChanged)
    dispatchListener.subscribe(signal: .DEREGISTER_DISPLAY_TREE, onTreePanelControllerDeregistered)
    dispatchListener.subscribe(signal: .SHUTDOWN_APP, shutdownApp)
    dispatchListener.subscribe(signal: .DIFF_TREES_DONE, afterDiffTreesDone)
    dispatchListener.subscribe(signal: .DIFF_TREES_FAILED, afterDiffTreesFailed)
    dispatchListener.subscribe(signal: .DIFF_TREES_CANCELLED, afterDiffExited)
    dispatchListener.subscribe(signal: .GENERATE_MERGE_TREE_DONE, afterMergeTreeGenerated)
    dispatchListener.subscribe(signal: .GENERATE_MERGE_TREE_FAILED, afterGenMergeTreeFailed)

    dispatchListener.subscribe(signal: .ERROR_OCCURRED, onErrorOccurred)

    // show Connection Problem window right away, cuz it might take a while to connect.
    // TODO: add a delay or something prettier
    self.grpcDidGoDown()
    try! self.backend.start()  // should not throw errors
    NSLog("INFO  Backend started")
  }

  func shutdown() throws {
    if self.wasShutdown {
      return
    }
    self.treeControllerLock.lock()
    defer {
      self.treeControllerLock.unlock()
    }
    for (treeID, controller) in self.treeControllerDict {
      do {
        try controller.shutdown()
      } catch {
        NSLog("ERROR [\(treeID)] Failed to shut down controller")
      }
    }

    // Close the app when mainWindow is closed, Windoze-style
    NSApplication.shared.terminate(0)

    self.wasShutdown = true
  }

  func grpcDidGoDown() {
    DispatchQueue.main.async {
      self.grpcDidGoDown_internal()
    }
  }

  private func grpcDidGoDown_internal() {
    DispatchQueue.main.async {
      NSLog("DEBUG Executing grpcDidGoDown(): mainWindowIsNull = \(self.mainWindow == nil)")
      self.enableWindowCloseListener = false
      // Close all other windows beside the Connection Problem window, if they exist
      self.mainWindow?.close()
      self.rootChooserView?.window.close()
      self.mergePreviewView?.window.close()
      self.enableWindowCloseListener = true

      self.settings.reset()

      // Open Connection Problem window
      NSLog("INFO  Showing ConnectionProblem window")
      do {
        if self.connectionProblemView != nil && self.connectionProblemView.isOpen {
          NSLog("DEBUG Closing existing ConnectionProblem window")
          self.connectionProblemView.window.close()
        }
        self.connectionProblemView = ConnectionProblemView(self, self._backend!.backendConnectionState)
        try self.connectionProblemView.start()
        self.connectionProblemView.showWindow()
      } catch {
        NSLog("ERROR Failed to open ConnectionProblem window: \(error)")
        self.displayError("Failed to open Connecting window!", "An unexpected error occurred: \(error)")
      }
    }
  }

  func grpcDidGoUp() {
    DispatchQueue.main.async {
      NSLog("INFO  grpcDidGoUp: '\(DispatchQueue.currentQueueLabel ?? "nil")'")
      do {
        try self.launchFrontend()
      } catch {
        if let grpcClient = self._backend, !grpcClient.isConnected {
          // we can handle a disconnect
          NSLog("ERROR While creating main window: \(error)")
          self.grpcDidGoDown_internal()

        } else { // unknown error...try to handle
          NSLog("ERROR while launching frontend: \(error)")
          self.grpcDidGoDown_internal()
        }
      }
    }
  }

  private func launchFrontend() throws {
    // These make gRPC calls and will be the first thing to fail if the BE is not online
    // (note: they will fail separately, since OutletGRPCClient operates on a separate thread)
    NSLog("DEBUG Entered launchFrontend()")
    try self.iconStore.start()

    settings.deviceList = try self.backend.getDeviceList()

    settings.isPlaying = try self.backend.getOpExecutionPlayState()

    // TODO: eventually refactor this so that all state is stored in BE, and we only supply the tree_id when we request the state
    let treeLeft: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
    let treeRight: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
    self.conLeft = try self.buildController(treeLeft, canChangeRoot: true, allowMultipleSelection: true)
    self.conRight = try self.buildController(treeRight, canChangeRoot: true, allowMultipleSelection: true)
    try self.conLeft!.requestTreeLoad()
    try self.conRight!.requestTreeLoad()

      self.connectionProblemView?.window.close()

      let screenSize = NSScreen.main?.frame.size ?? .zero
      NSLog("DEBUG Screen size is \(screenSize.width)x\(screenSize.height)")

      NSLog("DEBUG OutletMacApp start done")
      self.createMainWindow()
  }

  /**
   Creates and starts a tree controller for the given tree, but does not load it.

   NOTE:
  */
  private func buildController(_ tree: DisplayTree, canChangeRoot: Bool, allowMultipleSelection: Bool) throws -> TreePanelController {
    let filterCriteria: FilterCriteria = try backend.getFilterCriteria(treeID: tree.treeID)
    let con = try TreePanelController(app: self, tree: tree, filterCriteria: filterCriteria, canChangeRoot: canChangeRoot, allowMultipleSelection: allowMultipleSelection)

    try con.start()
    return con
  }

  private func loadWindowContentRectFromConfig() throws -> NSRect {
    NSLog("DEBUG Entered loadWindowContentRectFromConfig()")
    let xLocConfigPath = "ui_state.\(winID).x"
    let yLocConfigPath = "ui_state.\(winID).y"
    let widthConfigPath = "ui_state.\(winID).width"
    let heightConfigPath = "ui_state.\(winID).height"
    let winX : Int = try self.backend.getIntConfig(xLocConfigPath)
    let winY : Int = try self.backend.getIntConfig(yLocConfigPath)

    let winWidth : Int = try backend.getIntConfig(widthConfigPath)
    let winHeight : Int = try backend.getIntConfig(heightConfigPath)

    NSLog("DEBUG WinCoords: (\(winX), \(winY)), width/height: \(winWidth)x\(winHeight)")

    return NSRect(x: winX, y: winY, width: winWidth, height: winHeight)
  }

  private func createMainWindow() {
    // FIXME: actually get the app to use these values
    do {
      self.contentRect = try self.loadWindowContentRectFromConfig()
    } catch {
      // recoverable error: just use defaults
      NSLog("ERROR Failed to load contentRect from config: \(error)")
    }

    if mainWindow == nil {
      NSLog("DEBUG Creating mainWindow")
      mainWindow = NSWindow(
              contentRect: self.contentRect,
              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
              backing: .buffered, defer: false)
      mainWindow!.isReleasedWhenClosed = false  // i.e., don't crash when re-opening
      mainWindow!.delegate = self
      mainWindow!.title = "OutletMac"
    }

    NSLog("DEBUG Showing mainWindow")
    mainWindowIsOpen = true
    mainWindow!.makeKeyAndOrderFront(nil)
    let contentView = MainContentView(app: self, conLeft: self.conLeft!, conRight: self.conRight!).environmentObject(self.settings)
    mainWindow!.contentView = NSHostingView(rootView: contentView)
  }

  private func reportWinCoords() {
    let rect = self.contentRect
    NSLog("DEBUG [\(self.winID)] Firing timer to report mainWindow size: \(rect)")

    var configDict = [String: String]()
    configDict["ui_state.\(winID).x"] = String(Int(rect.minX))
    configDict["ui_state.\(winID).y"] = String(Int(rect.minY))
    configDict["ui_state.\(winID).width"] = String(Int(rect.width))
    configDict["ui_state.\(winID).height"] = String(Int(rect.height))

    do {
      try self.backend.putConfigList(configDict)
    } catch {
      NSLog("ERROR [\(self.winID)] Failed to report mainWindow size: \(error)")
      return
    }
  }

  // NSApplicationDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      try self.start()
    } catch OutletError.invalidArgument(let msg) {
      fatalError("Start failed: \(msg)")
    } catch {
      fatalError("Start faild with unexpected error: \(error)")
    }
  }

  // NSWindowDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  @objc func windowDidResize(_ notification: Notification) {
//    NSLog("DEBUG Main win resized! \(self.mainWindow?.frame.size as Any)")
    if let winFrame: CGRect = self.mainWindow?.frame {
      self.contentRect = winFrame
      self.winCoordsTimer.reschedule()
    }
  }

  @objc func windowDidMove(_ notification: Notification) {
//    NSLog("DEBUG Main win moved! \(self.mainWindow?.frame.origin as Any)")
    if let winFrame: CGRect = self.mainWindow?.frame {
      self.contentRect = winFrame
      self.winCoordsTimer.reschedule()
    }
  }

//  @objc func windowDidChangeScreen(_ notification: Notification) {
//    NSLog("WINDOW CHANGED SCREEN!!!!!")
//  }

  @objc func windowWillClose(_ notification: Notification) {
    self.mainWindowIsOpen = false

    if !self.enableWindowCloseListener {
      // closed by program, not user
      NSLog("DEBUG Closing mainWindow")

      self.execAsync {
        do {
          try self.conLeft?.shutdown()
          try self.conRight?.shutdown()
        } catch {
          NSLog("ERROR Failed to shut down tree controllers in mainWindow: \(error)")
        }
      }
      return
    }

    NSLog("DEBUG User closed mainWindow: closing app")
    do {
      try self.shutdown()
    } catch {
      NSLog("ERROR During application shutdown: \(error)")
    }
  }

  // Convenience methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  public func execAsync(_ workItem: @escaping NoArgVoidFunc) {
    self.taskRunner.execAsync(workItem)
  }

  public func execSync(_ workItem: @escaping NoArgVoidFunc) {
    self.taskRunner.execSync(workItem)
  }

  public func sendEnableUISignal(enable: Bool) {
    self.dispatcher.sendSignal(signal: .TOGGLE_UI_ENABLEMENT, senderID: ID_MAIN_WINDOW, ["enable": enable])
  }

  private func changeWindowMode(_ newMode: WindowMode) {
    DispatchQueue.main.async {
      NSLog("DEBUG Setting WindowMode to: \(newMode)")
      self.settings.mode = newMode
    }
  }

  // SignalDispatcher callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  // Displays any errors that are reported from the backend via gRPC
  private func onErrorOccurred(senderID: SenderID, propDict: PropDict) throws {
    let msg = try propDict.getString("msg")
    let secondaryMsg = try propDict.getString("secondary_msg")
    NSLog("ERROR Received error signal from '\(senderID)': msg='\(msg)' secondaryMsg='\(secondaryMsg)'")
    self.displayError(msg, secondaryMsg)
  }

  private func onEnableUIToggled(_ senderID: SenderID, _ propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("enable")
    DispatchQueue.main.async {
      self.settings.isUIEnabled = isEnabled
    }
  }

  private func onOpExecutionPlayStateChanged(senderID: SenderID, propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("is_enabled")
    DispatchQueue.main.async {
      self.settings.isPlaying = isEnabled
    }
  }

  private func onTreePanelControllerDeregistered(senderID: SenderID, propDict: PropDict) throws {
    self.deregisterTreePanelController(senderID)
  }

  private func shutdownApp(senderID: SenderID, propDict: PropDict) throws {
    try self.shutdown()
  }

  private func afterDiffTreesDone(senderID: SenderID, propDict: PropDict) throws {
    let leftTree = try propDict.get("tree_left") as! DisplayTree
    let rightTree = try propDict.get("tree_right") as! DisplayTree
    try self.conLeft!.updateDisplayTree(to: leftTree)
    try self.conRight!.updateDisplayTree(to: rightTree)
    // This will change the button bar:
    self.changeWindowMode(.DIFF)
    self.sendEnableUISignal(enable: true)
  }

  private func afterDiffTreesFailed(senderID: SenderID, propDict: PropDict) throws {
    // Change button bar back:
    self.changeWindowMode(.BROWSING)
    self.sendEnableUISignal(enable: true)
  }

  private func afterDiffExited(senderID: SenderID, propDict: PropDict) throws {
    let leftTree = try propDict.get("tree_left") as! DisplayTree
    let rightTree = try propDict.get("tree_right") as! DisplayTree
    try self.conLeft!.updateDisplayTree(to: leftTree)
    try self.conRight!.updateDisplayTree(to: rightTree)

    // This will change the button bar:
    self.changeWindowMode(.BROWSING)
    self.sendEnableUISignal(enable: true)
  }

  private func afterMergeTreeGenerated(senderID: SenderID, propDict: PropDict) throws {
    NSLog("DEBUG Got signal: \(Signal.GENERATE_MERGE_TREE_DONE)")
    let newTree = try propDict.get("tree") as! DisplayTree
    // Need to execute in a different queue, 'cuz buildController() makes a gRPC call, and we can't do that in a thread which came from gRPC
    do {
      // This will put the controller in the registry as a side effect
      let _ = try self.buildController(newTree, canChangeRoot: false, allowMultipleSelection: false)
      // note: we can't send a controller directly to this method (cuz of @objc), so instead we put it in our controller registry and later look it up.
      NSApp.sendAction(#selector(OutletMacApp.openMergePreview), to: nil, from: newTree.treeID)
    } catch {
      self.displayError("Failed to build merge tree", "\(error)")
    }
  }

  private func afterGenMergeTreeFailed(senderID: SenderID, propDict: PropDict) throws {
    // Re-enable UI:
    self.dispatcher.sendSignal(signal: .TOGGLE_UI_ENABLEMENT, senderID: ID_MAIN_WINDOW, ["enable": true])
  }

  // TreePanelController registry
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func registerTreePanelController(_ treeID: TreeID, _ controller: TreePanelControllable) {
    self.treeControllerLock.lock()
    defer {
      self.treeControllerLock.unlock()
    }
    self.treeControllerDict[treeID] = controller
  }

  func deregisterTreePanelController(_ treeID: TreeID) {
    self.treeControllerLock.lock()
    defer {
      self.treeControllerLock.unlock()
    }
    NSLog("DEBUG [\(treeID)] Deregistering tree controller in frontend")
    self.treeControllerDict.removeValue(forKey: treeID)
  }

  func getTreePanelController(_ treeID: TreeID) -> TreePanelControllable? {
    self.treeControllerLock.lock()
    defer {
      self.treeControllerLock.unlock()
    }
    return self.treeControllerDict[treeID]
  }

  // Etc
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Display error msg in dialog
   */
  func displayError(_ msg: String, _ secondaryMsg: String) {
      DispatchQueue.main.async {
        if self.connectionProblemView != nil && self.connectionProblemView.isOpen {
          NSLog("INFO  Will not display error alert ('\(msg)'): the Connection Problem window is open")
        } else if !self.mainWindowIsOpen {
          NSLog("INFO  Will not display error alert ('\(msg)'): the main window is not open to display it")
        } else {
          self.settings.showAlert(title: msg, msg: secondaryMsg)
        }
      }
  }

  /**
   Display dialog to confirm with user. Return TRUE if user says OK; FALSE if user cancels
   */
  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = messageText
    alert.informativeText = informativeText
    alert.addButton(withTitle: okButtonText)
    alert.addButton(withTitle: cancelButtonText)
    alert.alertStyle = .warning
    return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
  }

  /**
   Display GDrive root selection dialog
   */
  func openGDriveRootChooser(_ deviceUID: UID, _ treeID: String) {
    guard let sourceCon = self.getTreePanelController(treeID) else {
      NSLog("ERROR [\(treeID)] Cannot open GDrive Chooser: could not find controller with this treeID!")
      return
    }
    let currentSN: SPIDNodePair = sourceCon.tree.rootSN

    if rootChooserView != nil && rootChooserView.isOpen {
      rootChooserView.moveToFront()
      rootChooserView.selectSPID(currentSN.spid)
    } else {
      do {
        let tree: DisplayTree = try self.backend.createDisplayTreeForGDriveSelect(deviceUID: deviceUID)!
        let con = try self.buildController(tree, canChangeRoot: false, allowMultipleSelection: false)

        rootChooserView = GDriveRootChooser(self, con, initialSelection: currentSN, targetTreeID: treeID)
        try rootChooserView.start()
      } catch {
        self.displayError("Error opening Google Drive root chooser", "An unexpected error occurred: \(error)")
      }
    }
  }

  @objc func openMergePreview(_ treeID: TreeID) {
    if self.mergePreviewView != nil && self.mergePreviewView.isOpen {
      self.mergePreviewView.moveToFront()
    } else {
      // note: we can't send a controller directly to this method (cuz of @objc), so instead we look it up in our controller registry.
      guard let con = self.getTreePanelController(treeID) else {
        NSLog("ERROR [\(treeID)] Cannot open Merge Preview: could not find controller with this treeID!")
        return
      }

      DispatchQueue.main.async {
        do {
          self.mergePreviewView = MergePreview(self, con)
          try self.mergePreviewView.start()
        } catch {
          self.displayError("Error opening Merge Preview", "An unexpected error occurred: \(error)")
        }
      }
    }
  }
}
