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

  func execAsync(_ workItem: @escaping NoArgVoidFunc)
  func execSync(_ workItem: @escaping NoArgVoidFunc)

  func guidFor(_ treeType: TreeType, singlePath: String, uid: UID) -> GUID

  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool

  func registerTreePanelController(_ treeID: String, _ controller: TreePanelControllable)
  func getTreePanelController(_ treeID: String) -> TreePanelControllable?
}

class MockApp: OutletApp {
  var dispatcher: SignalDispatcher
  var backend: OutletBackend
  var iconStore: IconStore

  init() {
    self.dispatcher = SignalDispatcher()
    self.backend = MockBackend(self.dispatcher)
    self.iconStore = IconStore(self.backend)
  }

  func start() throws {
  }
  func shutdown() throws {
  }

  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
  }
  func execSync(_ workItem: @escaping NoArgVoidFunc) {
  }
  func guidFor(_ treeType: TreeType, singlePath: String, uid: UID) -> GUID {
    return 0
  }

  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool {
    return false
  }

  func registerTreePanelController(_ treeID: String, _ controller: TreePanelControllable) {
  }
  func getTreePanelController(_ treeID: String) -> TreePanelControllable? {
    return nil
  }
}

// This is awesome: https://medium.com/@theboi/macos-apps-without-storyboard-or-xib-menu-bar-in-swift-5-menubar-and-toolbar-6f6f2fa39ccb
class AppMenu: NSMenu {
  private lazy var applicationName = ProcessInfo.processInfo.processName

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
  var rootChooserView: GDriveRootChooser!
  var window: NSWindow!

  let winID = ID_MAIN_WINDOW
  let settings = GlobalSettings()
  let dispatcher = SignalDispatcher()
  lazy var dispatchListener: DispatchListener = dispatcher.createListener(winID)
  var _backend: OutletBackend? = nil
  var _iconStore: IconStore? = nil
  var conLeft: TreePanelController? = nil
  var conRight: TreePanelController? = nil
  let taskRunner: TaskRunner = TaskRunner()
  private var contentRect = NSRect(x: DEFAULT_MAIN_WIN_X, y: DEFAULT_MAIN_WIN_Y, width: DEFAULT_MAIN_WIN_WIDTH, height: DEFAULT_MAIN_WIN_HEIGHT)
  private lazy var winCoordsTimer = HoldOffTimer(WIN_SIZE_STORE_DELAY_MS, self.reportWinCoords)
  private let guidMapper = GUIDMapper()
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

  func start() throws {
    NSLog("DEBUG OutletMacApp start begin")

    do {
      self._backend = OutletGRPCClient.makeClient(host: "localhost", port: 50051, dispatcher: self.dispatcher)
      self._iconStore = IconStore(self.backend)

      NSLog("INFO  gRPC client connecting")
      try self.backend.start()
      NSLog("INFO  Backend started")

      try self.iconStore.start()

      // Subscribe to app-wide signals here
      try dispatchListener.subscribe(signal: .ERROR_OCCURRED, onErrorOccurred)
      try dispatchListener.subscribe(signal: .OP_EXECUTION_PLAY_STATE_CHANGED, onOpExecutionPlayStateChanged)
      try dispatchListener.subscribe(signal: .DEREGISTER_DISPLAY_TREE, onTreePanelControllerDeregistered)

      settings.isPlaying = try self.backend.getOpExecutionPlayState()

      // TODO: eventually refactor this so that all state is stored in BE, and we only supply the tree_id when we request the state
      let treeLeft: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      self.conLeft = try self.buildController(treeLeft, canChangeRoot: true, allowMultipleSelection: true)
      self.conRight = try self.buildController(treeRight, canChangeRoot: true, allowMultipleSelection: true)
      try self.conLeft!.loadTree()
      try self.conRight!.loadTree()

      let screenSize = NSScreen.main?.frame.size ?? .zero
      NSLog("DEBUG Screen size is \(screenSize.width)x\(screenSize.height)")

      NSLog("DEBUG OutletMacApp start done")
    } catch {
      NSLog("FATAL ERROR in OutletMacApp start(): \(error)")
      NSLog("DEBUG Sleeping 1s to let things settle...")
      sleep(1)
      exit(1)
    }
  }

  /**
   Creates and starts a tree controller for the given tree, but does not load it
  */
  func buildController(_ tree: DisplayTree, canChangeRoot: Bool, allowMultipleSelection: Bool) throws -> TreePanelController {
    let filterCriteria: FilterCriteria = try backend.getFilterCriteria(treeID: tree.treeID)
    let con = TreePanelController(app: self, tree: tree, filterCriteria: filterCriteria, canChangeRoot: canChangeRoot, allowMultipleSelection: allowMultipleSelection)

    try con.start()
    return con
  }

  func shutdown() throws {
    for (treeID, controller) in self.treeControllerDict {
      do {
        try controller.shutdown()
      } catch {
        NSLog("ERROR [\(treeID)] Failed to shut down controller")
      }
    }
  }

  private func loadWindowContentRectFromConfig() throws -> NSRect {
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

  private func createWindow() {
    // FIXME: actually get the app to use these values
    do {
      self.contentRect = try self.loadWindowContentRectFromConfig()
    } catch {
      // recoverable error: just use defaults
      NSLog("ERROR Failed to load contentRect from config: \(error)")
    }
    window = NSWindow(
      contentRect: self.contentRect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.delegate = self
    window.title = "OutletMac"
//    window.setFrameAutosaveName("OutletMac")
//    window.center()
    window.makeKeyAndOrderFront(nil)
    let contentView = MainContentView(app: self, conLeft: self.conLeft!, conRight: self.conRight!).environmentObject(self.settings)
    window.contentView = NSHostingView(rootView: contentView)
  }

  private func reportWinCoords() {
    let rect = self.contentRect
    NSLog("DEBUG [\(self.winID)] Firing timer to report window size: \(rect)")

    var configDict = [String: String]()
    configDict["ui_state.\(winID).x"] = String(Int(rect.minX))
    configDict["ui_state.\(winID).y"] = String(Int(rect.minY))
    configDict["ui_state.\(winID).width"] = String(Int(rect.width))
    configDict["ui_state.\(winID).height"] = String(Int(rect.height))

    do {
      try self.backend.putConfigList(configDict)
    } catch {
      NSLog("ERROR [\(self.winID)] Failed to report window size: \(error)")
      return
    }
  }

  // NSApplicationDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      try self.start()
      self.createWindow()
    } catch {
      NSLog("ERROR should not have gotten here: \(error)")
    }
  }

  // NSWindowDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  @objc func windowDidResize(_ notification: Notification) {
//    NSLog("DEBUG Main win resized! \(self.window?.frame.size as Any)")
    if let winFrame: CGRect = self.window?.frame {
      self.contentRect = winFrame
      self.winCoordsTimer.reschedule()
    }
  }

  @objc func windowDidMove(_ notification: Notification) {
//    NSLog("DEBUG Main win moved! \(self.window?.frame.origin as Any)")
    if let winFrame: CGRect = self.window?.frame {
      self.contentRect = winFrame
      self.winCoordsTimer.reschedule()
    }
  }

//  @objc func windowDidChangeScreen(_ notification: Notification) {
//    NSLog("WINDOW CHANGED SCREEN!!!!!")
//  }

  @objc func windowWillClose(_ notification: Notification) {
    NSLog("DEBUG User closed main window: closing app")
    do {
      try self.shutdown()
    } catch {
      NSLog("ERROR During application shutdown: \(error)")
    }
    // Close the app when window is closed, Windoze-style
    NSApplication.shared.terminate(0)
  }

  // Convenience methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  public func execAsync(_ workItem: @escaping NoArgVoidFunc) {
    self.taskRunner.execAsync(workItem)
  }

  public func execSync(_ workItem: @escaping NoArgVoidFunc) {
    self.taskRunner.execSync(workItem)
  }

  func guidFor(_ treeType: TreeType, singlePath: String, uid: UID) -> GUID {
    return self.guidMapper.guidFor(treeType, singlePath: singlePath, uid: uid)
  }

  // SignalDispatcher callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  // Displays any errors that are reported from the backend via gRPC
  private func onErrorOccurred(senderID: SenderID, propDict: PropDict) throws {
    let msg = try propDict.getString("msg")
    let secondaryMsg = try propDict.getString("secondary_msg")
    self.displayError(msg, secondaryMsg)
    DispatchQueue.main.async {
      self.settings.showAlert(title: msg, msg: secondaryMsg)
    }
  }

  private func onOpExecutionPlayStateChanged(senderID: SenderID, propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("is_enabled")
    DispatchQueue.main.async {
      self.settings.isPlaying = isEnabled
    }
  }

  private func onTreePanelControllerDeregistered(senderID: SenderID, propDict: PropDict) throws {
    self.treeControllerLock.lock()
    defer {
      self.treeControllerLock.unlock()
    }
    NSLog("DEBUG [\(senderID)] Deregistering tree controller in frontend")
    self.treeControllerDict.removeValue(forKey: senderID)
  }

  // Etc
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func displayError(_ msg: String, _ secondaryMsg: String) {
      DispatchQueue.main.async {
        self.settings.showAlert(title: msg, msg: secondaryMsg)
      }
  }

  @objc func openGDriveRootChooser(_ treeID: String) {
    guard let sourceCon = self.getTreePanelController(treeID) else {
      NSLog("ERROR [\(treeID)] Cannot open GDrive chooser: could not find controller with this treeID!")
      return
    }
    let currentSN: SPIDNodePair = sourceCon.tree.rootSN

    if rootChooserView != nil && rootChooserView.isOpen {
      rootChooserView.moveToFront()
      rootChooserView.selectSPID(currentSN.spid)
    } else {
      do {
        let tree: DisplayTree = try self.backend.createDisplayTreeForGDriveSelect()!
        let con = try self.buildController(tree, canChangeRoot: false, allowMultipleSelection: false)

        rootChooserView = GDriveRootChooser(self, con, targetTreeID: treeID, initialSelection: currentSN)
        try rootChooserView.start()
      } catch {
        self.displayError("Error opening Google Drive root chooser", "An unexpected error occurred: \(error)")
      }
    }
  }

  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = messageText
    alert.informativeText = informativeText
    alert.addButton(withTitle: okButtonText)
    alert.addButton(withTitle: cancelButtonText)
    alert.alertStyle = .warning
    return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
  }

  func registerTreePanelController(_ treeID: String, _ controller: TreePanelControllable) {
    self.treeControllerLock.lock()
    defer {
      self.treeControllerLock.unlock()
    }
    self.treeControllerDict[treeID] = controller
  }

  func getTreePanelController(_ treeID: String) -> TreePanelControllable? {
    self.treeControllerLock.lock()
    defer {
      self.treeControllerLock.unlock()
    }
    return self.treeControllerDict[treeID]
  }
}
