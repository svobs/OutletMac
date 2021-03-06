//
//  AppDelegate.swift
//  OutlineView
//
//  Created by Toph Allen on 4/13/20.
//  Copyright © 2020 Toph Allen. All rights reserved.
//
import AppKit
import Cocoa
import SwiftUI

/**
 PROTOCOL OutletApp
 */
protocol OutletApp {
  var dispatcher: SignalDispatcher { get }
  var backend: OutletBackend { get }

  func execAsync(_ workItem: @escaping NoArgVoidFunc)
  func execSync(_ workItem: @escaping NoArgVoidFunc)
}

class MockApp: OutletApp {
  var dispatcher: SignalDispatcher
  var backend: OutletBackend

  init() {
    self.dispatcher = SignalDispatcher()
    self.backend = MockBackend(self.dispatcher)
  }

  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
  }
  func execSync(_ workItem: @escaping NoArgVoidFunc) {
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
  var preferencesWindow: NSWindow!
  var window: NSWindow!

  let winID = ID_MAIN_WINDOW
  let settings = GlobalSettings()
  let dispatcher = SignalDispatcher()
  // TODO: surely Swift has a better way to init these
  var dispatchListener: DispatchListener? = nil
  var _backend: OutletBackend? = nil
  var conLeft: TreeController? = nil
  var conRight: TreeController? = nil
  let taskRunner: TaskRunner = TaskRunner()
  private var contentRect = NSRect(x: DEFAULT_MAIN_WIN_X, y: DEFAULT_MAIN_WIN_Y, width: DEFAULT_MAIN_WIN_WIDTH, height: DEFAULT_MAIN_WIN_HEIGHT)
  private lazy var winCoordsTimer = HoldOffTimer(WIN_SIZE_STORE_DELAY_MS, self.reportWinCoords)

  var backend: OutletBackend {
    get {
      return self._backend!
    }
  }

  func start() {
    NSLog("DEBUG OutletMacApp start begin")

    do {
      self._backend = OutletGRPCClient.makeClient(host: "localhost", port: 50051, dispatcher: self.dispatcher)

      NSLog("INFO  gRPC client connecting")
      try self.backend.start()
      NSLog("INFO  Backend started")

      // Subscribe to app-wide signals here
      dispatchListener = dispatcher.createListener(winID)
      try dispatchListener!.subscribe(signal: .ERROR_OCCURRED, onErrorOccurred)
      try dispatchListener!.subscribe(signal: .OP_EXECUTION_PLAY_STATE_CHANGED, onOpExecutionPlayStateChanged)

      settings.isPlaying = try self.backend.getOpExecutionPlayState()

      // TODO: eventually refactor this so that all state is stored in BE, and we only supply the tree_id when we request the state
      let treeLeft: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      let filterCriteriaLeft: FilterCriteria = try backend.getFilterCriteria(treeID: ID_LEFT_TREE)
      let filterCriteriaRight: FilterCriteria = try backend.getFilterCriteria(treeID: ID_RIGHT_TREE)
      self.conLeft = TreeController(app: self, tree: treeLeft, filterCriteria: filterCriteriaLeft)
      self.conRight = TreeController(app: self, tree: treeRight, filterCriteria: filterCriteriaRight)

      try conLeft!.start()
      try conLeft!.loadTree()
      try conRight!.start()
      try conRight!.loadTree()

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
    // FIXME
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
//    window.level = .floating
    settings.mainWindowHeight = self.contentRect.height
    NSLog("DEBUG Window height = \(settings.mainWindowHeight)")
    window.delegate = self
    window.title = "OutletMac"
    window.setFrameAutosaveName("OutletMac")
    window.center()
    window.makeKeyAndOrderFront(nil)
    let contentView = ContentView(app: self, conLeft: self.conLeft!, conRight: self.conRight!).environmentObject(self.settings)
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
    self.start()
    self.createWindow()
  }

  // NSWindowDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  @objc func windowDidResize(_ notification: Notification) {
    NSLog("DEBUG Main win resized! \(self.window?.frame.size as Any)")
    if let winFrame: CGRect = self.window?.frame {
      self.settings.mainWindowHeight = winFrame.size.height
      NSLog("DEBUG Window height = \(settings.mainWindowHeight)")
      self.contentRect = winFrame
      self.winCoordsTimer.reschedule()
    }
  }

  @objc func windowDidMove(_ notification: Notification) {
    NSLog("DEBUG Main win moved! \(self.window?.frame.origin as Any)")
    if let winFrame: CGRect = self.window?.frame {
      self.settings.mainWindowHeight = winFrame.size.height
      NSLog("DEBUG Window height = \(settings.mainWindowHeight)")
      self.contentRect = winFrame
      self.winCoordsTimer.reschedule()
    }
  }

//  @objc func windowDidChangeScreen(_ notification: Notification) {
//    NSLog("WINDOW CHANGED SCREEN!!!!!")
//  }

  @objc func windowWillClose(_ notification: Notification) {
    NSLog("DEBUG User closed main window: closing app")
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

  // SignalDispatcher callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  // Displays any errors that are reported from the backend via gRPC
  private func onErrorOccurred(senderID: SenderID, propDict: PropDict) throws {
    let msg = try propDict.getString("msg")
    let secondaryMsg = try propDict.getString("secondary_msg")
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

  // Etc
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  @objc func openPreferencesWindow() {
    if nil == preferencesWindow {      // create once !!
      let preferencesView = PrefsView()
      // Create the preferences window and set content
      preferencesWindow = NSWindow(
        contentRect: NSRect(x: 20, y: 20, width: 480, height: 300),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false)
      preferencesWindow.center()
      preferencesWindow.setFrameAutosaveName("Preferences")
      preferencesWindow.isReleasedWhenClosed = false
      preferencesWindow.contentView = NSHostingView(rootView: preferencesView)
    }
    preferencesWindow.makeKeyAndOrderFront(nil)
  }

}
