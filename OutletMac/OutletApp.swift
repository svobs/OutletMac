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

  var globalState: GlobalState { get }

  var serialQueue: DispatchQueue { get }

  func grpcDidGoDown()
  func grpcDidGoUp()
  func execAsync(_ workItem: @escaping NoArgVoidFunc)
  func execSync(_ workItem: @escaping NoArgVoidFunc)

  func displayError(_ msg: String, _ secondaryMsg: String)
  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool

  func buildController(_ tree: DisplayTree, canChangeRoot: Bool, allowsMultipleSelection: Bool) throws -> TreePanelController
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
  // Windows which ARE reused:
  var connectionProblemWindow: ConnectionProblemWindow! = nil
  var mainWindow: MainWindow? = nil

  // Windows which ARE NOT reused... TODO: test opening & closing these lots of times
  var rootChooserWindow: GDriveRootChooserWindow? = nil
  var mergePreviewWindow: MergePreviewWindow? = nil

  private var wasShutdown: Bool = false

  let globalState = GlobalState()
  let dispatcher = SignalDispatcher()
  let dispatchListener: DispatchListener
  private var _backend: OutletGRPCClient?
  private var _iconStore: IconStore? = nil

  let serialQueue = DispatchQueue(label: "App-SerialQueue") // custom dispatch queues are serial by default

  private let tcDQ = DispatchQueue(label: "TreeControllerDict-SerialQueue")

  /**
   This should be the ONLY place where strong references to TreePanelControllables are stored.
   Everything else should be a weak ref. Thus, when deregisterTreePanelController() is called, the only ref
   is deleted.
   */
  private var treeControllerDict: [String: TreePanelControllable] = [:]

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
    self.dispatchListener = self.dispatcher.createListener(ID_APP)

    // Enable detection of our custom queue, for debugging and assertions:
    DispatchQueue.registerDetection(of: self.serialQueue)
    DispatchQueue.registerDetection(of: self.tcDQ)

    super.init()
  }

  func start() throws {
    NSLog("DEBUG [\(ID_APP)] OutletMacApp starting: CurrentDispatchQueue='\(DispatchQueue.currentQueueLabel ?? "nil")'")

    // Subscribe to app-wide signals here
    dispatchListener.subscribe(signal: .DIFF_TREES_CANCELLED, afterDiffExited)
    dispatchListener.subscribe(signal: .GENERATE_MERGE_TREE_DONE, afterMergeTreeGenerated)
    dispatchListener.subscribe(signal: .OP_EXECUTION_PLAY_STATE_CHANGED, onOpExecutionPlayStateChanged)
    dispatchListener.subscribe(signal: .DEREGISTER_DISPLAY_TREE, onTreePanelControllerDeregistered)
    dispatchListener.subscribe(signal: .SHUTDOWN_APP, shutdownApp)
    dispatchListener.subscribe(signal: .ERROR_OCCURRED, onErrorOccurred)

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

    self.connectionProblemWindow = ConnectionProblemWindow(self, self._backend!.backendConnectionState)

    // show Connection Problem window right away, cuz it might take a while to connect.
    // TODO: add a delay or something prettier
    self.grpcDidGoDown()
    try! self.backend.start()  // should not throw errors
    NSLog("INFO  Backend started")
  }

  func shutdown() throws {
    self.tcDQ.sync {
      if self.wasShutdown {
        return
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
  }

  func grpcDidGoDown() {
    DispatchQueue.main.async {
      NSLog("DEBUG [\(ID_APP)] Entered grpcDidGoDown()")

      self.openConnectionProblemWindow()
    }
  }

  func grpcDidGoUp() {
    NSLog("DEBUG [\(ID_APP)] Entered grpcDidGoUp()")
    DispatchQueue.main.async {
      do {
        try self.iconStore.start()
        self.globalState.deviceList = try self.backend.getDeviceList()
        self.globalState.isPlaying = try self.backend.getOpExecutionPlayState()

        let screenSize = NSScreen.main?.frame.size ?? .zero
        NSLog("DEBUG [\(ID_APP)] Screen size is \(screenSize.width)x\(screenSize.height)")

        self.openMainWindow()

      } catch {
        NSLog("ERROR [\(ID_APP)] while launching frontend: \(error)")
        self.grpcDidGoDown()
      }

    } // END .main.async
  }

  public func sendEnableUISignal(enable: Bool) {
    self.dispatcher.sendSignal(signal: .TOGGLE_UI_ENABLEMENT, senderID: ID_MAIN_WINDOW, ["enable": enable])
  }

  // SignalDispatcher callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Displays any errors that are reported from the backend via gRPC
   */
  private func onErrorOccurred(senderID: SenderID, propDict: PropDict) throws {
    let msg = try propDict.getString("msg")
    let secondaryMsg = try propDict.getString("secondary_msg")
    NSLog("ERROR  Received error signal from '\(senderID)': msg='\(msg)' secondaryMsg='\(secondaryMsg)'")
    self.displayError(msg, secondaryMsg)
  }

  private func onOpExecutionPlayStateChanged(senderID: SenderID, propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("is_enabled")
    DispatchQueue.main.async {
      self.globalState.isPlaying = isEnabled
    }
  }

  private func onTreePanelControllerDeregistered(senderID: SenderID, propDict: PropDict) throws {
    self.execSync {
      self.deregisterTreePanelController(senderID)
    }
  }

  private func shutdownApp(senderID: SenderID, propDict: PropDict) throws {
    try self.shutdown()
  }

  private func afterDiffExited(senderID: SenderID, propDict: PropDict) throws {
    // This signal is also emitted after merge is done. We are not the only listener for this: see MainWindow
    DispatchQueue.main.async {
      self.mergePreviewWindow?.close()
    }
  }

  private func afterMergeTreeGenerated(senderID: SenderID, propDict: PropDict) throws {
    NSLog("DEBUG [\(ID_APP)] Got signal: \(Signal.GENERATE_MERGE_TREE_DONE)")
    let newTree = try propDict.get("tree") as! DisplayTree
    // Need to execute in a different queue, 'cuz buildController() makes a gRPC call, and we can't do that in a thread which came from gRPC
    do {
      // This will put the controller in the registry as a side effect
      let _ = try self.buildController(newTree, canChangeRoot: false, allowsMultipleSelection: false)
      // note: we can't send a controller directly to this method (cuz of @objc), so instead we put it in our controller registry and later look it up.
      NSApp.sendAction(#selector(OutletMacApp.openMergePreview), to: nil, from: newTree.treeID)
    } catch {
      self.displayError("Failed to build merge tree", "\(error)")
    }
  }

  // NSApplicationDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      try self.start()
    } catch OutletError.invalidArgument(let msg) {
      fatalError("OutletApp.start() failed: \(msg)")
    } catch {
      fatalError("OutletApp.start() failed with unexpected error: \(error)")
    }
  }

  // Convenience methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
    self.serialQueue.async(execute: workItem)
  }

  func execSync(_ workItem: @escaping NoArgVoidFunc) {
    assert(DispatchQueue.isNotExecutingIn(self.serialQueue))

    self.serialQueue.sync(execute: workItem)
  }

  // TreePanelController registry
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Creates and starts a tree controller for the given tree, but does not load it.
  */
  public func buildController(_ tree: DisplayTree, canChangeRoot: Bool, allowsMultipleSelection: Bool) throws -> TreePanelController {
    let filterCriteria: FilterCriteria = try backend.getFilterCriteria(treeID: tree.treeID)
    let con = try TreePanelController(app: self, tree: tree, filterCriteria: filterCriteria, canChangeRoot: canChangeRoot, allowsMultipleSelection: allowsMultipleSelection)

    self.registerTreePanelController(con.treeID, con)
    try con.start()
    return con
  }

  func registerTreePanelController(_ treeID: TreeID, _ controller: TreePanelControllable) {
    self.tcDQ.sync {
      NSLog("DEBUG [\(treeID)] Registering tree controller in frontend")
      self.treeControllerDict[treeID] = controller
    }
  }

  func deregisterTreePanelController(_ treeID: TreeID) {
    self.tcDQ.sync {
      NSLog("DEBUG [\(treeID)] Deregistering tree controller in frontend")
      self.treeControllerDict.removeValue(forKey: treeID)
    }
  }

  func getTreePanelController(_ treeID: TreeID) -> TreePanelControllable? {
    assert(DispatchQueue.isNotExecutingIn(self.tcDQ))

    var con: TreePanelControllable?
    self.tcDQ.sync {
      con = self.treeControllerDict[treeID]
    }
    return con
  }

  // Display Dialog methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Display error msg in dialog
   */
  func displayError(_ msg: String, _ secondaryMsg: String) {
      self.tcDQ.sync {
        if self._backend!.isConnected {
          self.globalState.showAlert(title: msg, msg: secondaryMsg)
        } else {
          NSLog("INFO  [\(ID_APP)] Will not display error alert ('\(msg)'): the Connection Problem window is open")
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

    if let rootChooser = self.rootChooserWindow, rootChooser.isOpen {
      DispatchQueue.main.async {
        rootChooser.showWindow()
        rootChooser.selectSPID(currentSN.spid)
      }
    } else {
      do {
        let tree: DisplayTree = try self.backend.createDisplayTreeForGDriveSelect(deviceUID: deviceUID)!
        let con = try self.buildController(tree, canChangeRoot: false, allowsMultipleSelection: false)

        let window = GDriveRootChooserWindow(self, con, initialSelection: currentSN, targetTreeID: treeID)
        try window.start()
        window.showWindow()
        self.rootChooserWindow = window
      } catch {
        self.displayError("Error opening Google Drive root chooser", "An unexpected error occurred: \(error)")
      }
    }
  }

  /**
   Display Merge Preview dialog
   */
  @objc func openMergePreview(_ treeID: TreeID) {
    // note: we can't send a controller directly to this method (cuz of @objc), so instead we look it up in our controller registry.
    guard let con = self.getTreePanelController(treeID) else {
      NSLog("ERROR [\(treeID)] Cannot open Merge Preview: could not find controller with this treeID!")
      return
    }

    DispatchQueue.main.async {
      self.mergePreviewWindow?.close()

      do {
        let window = MergePreviewWindow(self, con)
        try window.start()
        window.showWindow()
        self.mergePreviewWindow = window
      } catch {
        self.displayError("Error opening Merge Preview", "An unexpected error occurred: \(error)")
      }
    }
  }

  /**
   Display Connection Problem dialog
   */
  func openConnectionProblemWindow() {
    assert(DispatchQueue.isExecutingIn(.main))

    self.globalState.reset()

    self.tcDQ.sync {

      NSLog("DEBUG [\(ID_APP)] Closing other windows besides ConnectionProblemWindow")
      // Close all other windows beside the Connection Problem window, if they exist
      self.mainWindow?.closeWithoutAppShutdown()
      self.rootChooserWindow?.close()
      self.mergePreviewWindow?.close()

      // Open Connection Problem window
      NSLog("INFO  [\(ID_APP)] Showing ConnectionProblem window")
      do {
        try self.connectionProblemWindow!.start()
        DispatchQueue.main.async {
          NSLog("DEBUG [\(ID_APP)] Calling ConnectionProblem.showWindow()")
          self.connectionProblemWindow!.showWindow()
        }
      } catch {
        NSLog("ERROR [\(ID_APP)] Failed to open ConnectionProblem window: \(error)")
        self.displayError("Failed to open Connecting window!", "An unexpected error occurred: \(error)")
      }
    }
  }

  /**
   Display main window
   */
  private func openMainWindow() {
    NSLog("DEBUG [\(ID_APP)] Entered openMainWindow()")

    do {
      if self.mainWindow == nil {
        // FIXME: actually get the app to use these values
        var contentRect: NSRect? = nil
        do {
          contentRect = try self.loadMainWindowContentRectFromConfig(ID_MAIN_WINDOW)
        } catch {
          // recoverable error: just use defaults
          NSLog("ERROR [\(ID_MAIN_WINDOW)] Failed to load contentRect from config: \(error)")
        }
        self.mainWindow = MainWindow(self, contentRect)
      }

      // TODO: eventually refactor this so that all state is stored in BE, and we only supply the tree_id when we request the state
      let treeLeft: DisplayTree = try self.backend.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try self.backend.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      let conLeft = try self.buildController(treeLeft, canChangeRoot: true, allowsMultipleSelection: true)
      let conRight = try self.buildController(treeRight, canChangeRoot: true, allowsMultipleSelection: true)

      self.tcDQ.sync {
        self.mainWindow?.closeWithoutAppShutdown()
        do {
          self.mainWindow!.setControllers(left: conLeft, right: conRight)
          try self.mainWindow!.start()
          DispatchQueue.main.async {
            NSLog("DEBUG [\(ID_APP)] Calling MainWindow.showWindow()")
            self.mainWindow!.showWindow()
          }

          // Close Connection Problem window if it is open:
          self.connectionProblemWindow?.close()
        } catch {
          NSLog("ERROR [\(ID_APP)] while starting main window: \(error)")
        }
      }

      NSLog("DEBUG [\(ID_APP)] Done creating mainWindow")
    } catch {
      NSLog("ERROR [\(ID_APP)] while opening main window: \(error)")
      self.grpcDidGoDown()
    }
  }

  private func loadMainWindowContentRectFromConfig(_ winID: String) throws -> NSRect {
    NSLog("DEBUG [\(ID_APP)] Entered loadWindowContentRectFromConfig()")
    let xLocConfigPath = "ui_state.\(winID).x"
    let yLocConfigPath = "ui_state.\(winID).y"
    let widthConfigPath = "ui_state.\(winID).width"
    let heightConfigPath = "ui_state.\(winID).height"
    let winX : Int = try self.backend.getIntConfig(xLocConfigPath)
    let winY : Int = try self.backend.getIntConfig(yLocConfigPath)

    let winWidth : Int = try backend.getIntConfig(widthConfigPath)
    let winHeight : Int = try backend.getIntConfig(heightConfigPath)

    NSLog("DEBUG [\(ID_APP)] WinCoords: (\(winX), \(winY)), width/height: \(winWidth)x\(winHeight)")

    return NSRect(x: winX, y: winY, width: winWidth, height: winHeight)
  }

}
