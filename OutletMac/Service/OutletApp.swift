//
//  OutletAppProtocol.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 1/6/21.
//
import AppKit
import Cocoa
import SwiftUI
import OutletCommon

/**
 PROTOCOL OutletAppProtocol
 */
protocol OutletAppProtocol: HasLifecycle, NSUserInterfaceValidations {
  // Services:
  var dispatcher: SignalDispatcher { get }
  var backend: OutletBackend { get }
  var iconStore: IconStore { get }

  // State:
  var globalState: GlobalState { get }
  var globalActions: GlobalActions { get }

  func grpcDidGoDown()
  func grpcDidGoUp()

  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool

  func buildController(_ tree: DisplayTree, canChangeRoot: Bool, allowsMultipleSelection: Bool) throws -> TreeController
  func registerTreePanelController(_ treeID: String, _ controller: TreeControllable)
  func deregisterTreePanelController(_ treeID: TreeID)
  func reregisterTreePanelController(oldTreeID: TreeID, newTreeID: TreeID, _ controller: TreeControllable)
  func getTreePanelController(_ treeID: String) -> TreeControllable?

  func sendEnableUISignal(enable: Bool)

  func openGDriveRootChooser(_ deviceUID: UID, _ treeID: String)
}

class OutletMacApp: NSObject, NSApplicationDelegate, OutletAppProtocol {

  override init() {
    self.dispatchListener = self.dispatcher.createListener(ID_APP)

    // Enable detection of our custom queue, for debugging and assertions:
    DispatchQueue.registerDetection(of: self.tcDQ)

    super.init()
    self.globalActions.app = self
  }

  // Member variables & accessors
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  // Windows which ARE reused:
  var connectionProblemWindow: ConnectionProblemWindow! = nil
  var mainWindow: MainWindow? = nil
  var gdriveRootChooserWindow: GDriveRootChooserWindow? = nil
  var mergePreviewWindow: MergePreviewWindow? = nil

  private var wasShutdown: Bool = false

  let globalActions = GlobalActions()
  let globalState = GlobalState()
  let dispatcher = SignalDispatcher()
  let dispatchListener: DispatchListener
  private var _backend: GRPCClientBackend?
  private var _iconStore: IconStore? = nil

  private let tcDQ = DispatchQueue(label: "TreeControllerDict-SerialQueue")

  private var eventMonitor: GlobalEventMonitor? = nil

  /**
   This should be the ONLY place where strong references to TreePanelControllables are stored.
   Everything else should be a weak ref. Thus, when deregisterTreePanelController() is called, the only ref
   is deleted.
   */
  private var treeControllerDict: [String: TreeControllable] = [:]

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

  // Lifecycle methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func start() throws {
    NSLog("DEBUG [\(ID_APP)] OutletMacApp starting: CurrentDispatchQueue='\(DispatchQueue.currentQueueLabel ?? "nil")'")

    // Subscribe to app-wide signals here
    dispatchListener.subscribe(signal: .DEVICE_UPSERTED, onDeviceUpserted)
    dispatchListener.subscribe(signal: .DIFF_TREES_CANCELLED, afterDiffExited)
    dispatchListener.subscribe(signal: .GENERATE_MERGE_TREE_DONE, afterMergeTreeGenerated)
    dispatchListener.subscribe(signal: .OP_EXECUTION_PLAY_STATE_CHANGED, onOpExecutionPlayStateChanged)
    dispatchListener.subscribe(signal: .DEREGISTER_DISPLAY_TREE, onTreePanelControllerDeregistered)
    dispatchListener.subscribe(signal: .SHUTDOWN_APP, shutdownApp)
    dispatchListener.subscribe(signal: .ERROR_OCCURRED, onErrorOccurred)
    dispatchListener.subscribe(signal: .BATCH_FAILED, onBatchFailed)
    dispatchListener.subscribe(signal: .EXECUTE_ACTION, onExecuteActionRequest)

    let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .flagsChanged]
    let eventMonitor =  GlobalEventMonitor(mask: eventMask, handler: self.onGlobalEvent)
    eventMonitor.start()
    self.eventMonitor = eventMonitor

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

    self._backend = GRPCClientBackend(self, useFixedAddress: useFixedAddress, fixedHost: fixedHost, fixedPort: fixedPort)
    self._iconStore = IconStore(self.backend)

    // show Connection Problem window right away, cuz it might take a while to connect.
    // TODO: add a delay or something prettier
    self.grpcDidGoDown()
    try! self.backend.start()  // should not throw errors
    NSLog("INFO  [\(ID_APP)] Backend started")
  }

  func shutdown() throws {
    self.tcDQ.sync {
      if self.wasShutdown {
        return
      }

      NSLog("INFO  [\(ID_APP)] OutletMacApp shutting down")

      self.eventMonitor?.stop()

      for (treeID, controller) in self.treeControllerDict {
        do {
          try controller.shutdown()
        } catch {
          NSLog("ERROR [\(treeID)] Failed to shut down controller")
        }
      }
      NSApplication.shared.terminate(0)

      self.wasShutdown = true
    }
  }

  // Umm. Misc stuff
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func grpcDidGoDown() {
    DispatchQueue.main.async {
      NSLog("DEBUG [\(ID_APP)] Entered grpcDidGoDown()")
      self._backend!.grpcConnectionDown()
      self.openConnectionProblemWindow()
    }
  }

  // This should only be called by GRPCClientBackend, when it is indeed back up.
  func grpcDidGoUp() {
    NSLog("DEBUG [\(ID_APP)] Entered grpcDidGoUp()")
    DispatchQueue.main.async {
      do {
        try self.iconStore.start()
        self.globalState.deviceList = try self.backend.getDeviceList()
        self.globalState.isBackendOpExecutorRunning = try self.backend.getOpExecutionPlayState()

        self.globalState.currentDragOperation = DragOperation(rawValue: try self.backend.getUInt32Config(DRAG_MODE_CONFIG_PATH,
                defaultVal: self.globalState.currentDragOperation.rawValue))!
        self.globalState.currentDirConflictPolicy = DirConflictPolicy(rawValue: try self.backend.getUInt32Config(DIR_CONFLICT_POLICY_CONFIG_PATH,
                defaultVal: self.globalState.currentDirConflictPolicy.rawValue))!
        self.globalState.currentFileConflictPolicy = FileConflictPolicy(rawValue: try self.backend.getUInt32Config(FILE_CONFLICT_POLICY_CONFIG_PATH,
                defaultVal: self.globalState.currentFileConflictPolicy.rawValue))!

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

  private func onGlobalEvent(_ event: NSEvent?) {
    if TRACE_ENABLED {
      NSLog("DEBUG Got global event: \(event == nil ? "null" : "\(event!)")")
    }
  }

  func reportError(_ msg: String, _ secondaryMsg: String) {
    NSLog("ERROR Error from OutletApp: msg='\(msg)' secondaryMsg='\(secondaryMsg)'")
    self.displayError(msg, secondaryMsg)
  }

  func reportException(_ title: String, _ error: Error) {
    let errorMsg: String = "\(error)"
    reportError(title, errorMsg)
  }


  // SignalDispatcher callbacks
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Displays any errors that are reported from the backend via gRPC
   */
  private func onErrorOccurred(senderID: SenderID, propDict: PropDict) throws {
    let msg = try propDict.getString("msg")
    let secondaryMsg = try propDict.getString("secondary_msg")
    NSLog("ERROR Received error signal from '\(senderID)': msg='\(msg)' secondaryMsg='\(secondaryMsg)'")
    self.displayError(msg, secondaryMsg)
  }

  private func handleBatchFailedModalResponse(_ response: NSApplication.ModalResponse, batchUID: UID) {
    let strategy: ErrorHandlingStrategy
    switch response {
    case NSApplication.ModalResponse.alertFirstButtonReturn:
      strategy = .CANCEL_BATCH
      NSLog("INFO  User chose to cancel batch (failed batch_uid='\(batchUID)')")
    case NSApplication.ModalResponse.alertSecondButtonReturn:
      strategy = .PROMPT
      NSLog("INFO  User chose to retry batch (failed batch_uid='\(batchUID)')")
    case NSApplication.ModalResponse.alertThirdButtonReturn:
      NSLog("INFO  User chose to pause batch intake (failed batch_uid='\(batchUID)')")
      return
    default:
      fatalError("Unknown response from Failed Batch alert!")
    }

    self.dispatcher.sendSignal(signal: .HANDLE_BATCH_FAILED, senderID: ID_APP, ["batch_uid": batchUID, "error_handling_strategy": strategy])
  }

  private func onBatchFailed(senderID: SenderID, propDict: PropDict) throws {
    let batchUID = try propDict.getUInt32("batch_uid")
    let msg = try propDict.getString("msg")
    let secondaryMsg = try propDict.getString("secondary_msg")
    NSLog("INFO  Received BatchFailed signal from '\(senderID)': batchUID='\(batchUID)' msg='\(msg)' secondaryMsg='\(secondaryMsg)'")
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.messageText = "Failed to submit batch \(batchUID):\n\"\(msg)\""
      alert.informativeText = "\(secondaryMsg)\n\nHow would you like to proceed?"
      alert.addButton(withTitle: "Cancel Batch")
      alert.addButton(withTitle: "Retry Batch")
      alert.addButton(withTitle: "Pause Batch Intake")
      alert.alertStyle = .warning
      // FIXME! If server disconnects then reconnects while this dialog is open, we should NOT
      // kill the window! This will cause the app to crash!
      if let window = self.mainWindow, window.isOpen {
        // run attached to main window, if available
        alert.beginSheetModal(for: window, completionHandler: { response in
          self.handleBatchFailedModalResponse(response, batchUID: batchUID)
        })
      } else {
        // just run a modal dialog if no window
        let response = alert.runModal()
        self.handleBatchFailedModalResponse(response, batchUID: batchUID)
      }
    }
  }

  private func onExecuteActionRequest(senderID: SenderID, propDict: PropDict) throws {
    let treeActionList = try propDict.get("action_list") as! [TreeAction]
    NSLog("DEBUG Got \(Signal.EXECUTE_ACTION) signal from '\(senderID)' with \(treeActionList.count) tree actions")
    for treeAction in treeActionList {
      if let con = self.getTreePanelController(treeAction.treeID) {
        con.treeActions.executeTreeAction(treeAction)
      } else {
        NSLog("ERROR Failed to find tree controller for treeID '\(treeAction.treeID)'; discarding action \(treeAction.actionType)")
      }
    }
  }

  private func onOpExecutionPlayStateChanged(senderID: SenderID, propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("is_enabled")
    DispatchQueue.main.async {
      self.globalState.isBackendOpExecutorRunning = isEnabled
    }
  }

  private func onTreePanelControllerDeregistered(senderID: SenderID, propDict: PropDict) throws {
    self.deregisterTreePanelController(senderID)
  }

  private func shutdownApp(senderID: SenderID, propDict: PropDict) throws {
    try self.shutdown()
  }

  private func onDeviceUpserted(senderID: SenderID, propDict: PropDict) throws {
    let upsertedDevice = try propDict.get("device") as! Device
    NSLog("DEBUG [\(ID_APP)] Got signal: \(Signal.DEVICE_UPSERTED) with device: \(upsertedDevice). Will refresh cached device list")

    DispatchQueue.main.async {
      // Just update all devices rather than bother with complex logic. Very infrequent, and inexpensive
      do {
        self.globalState.deviceList = try self.backend.getDeviceList()
      } catch {
        NSLog("ERROR [\(ID_APP)] while launching frontend: \(error)")
        self.grpcDidGoDown()
      }
    }
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
      let con = try self.buildController(newTree, canChangeRoot: false, allowsMultipleSelection: false)

      DispatchQueue.main.async {
        self.openMergePreview(con)
      }
    } catch {
      self.displayError("Failed to build merge tree", "\(error)")
      self.sendEnableUISignal(enable: true)
    }
  }

  // NSApplicationDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼
  func applicationDockMenu(sender: NSApplication) -> NSMenu? {
    // TODO
    let menu = NSMenu(title: "")
//    let clickMe = NSMenuItem(title: "ClickMe", action: "didSelectClickMe", keyEquivalent: "C")
//    clickMe.target = self

    return menu
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  func applicationDidFinishLaunching(_ notification: Notification) {

    let menu = AppMainMenu()
    menu.buildMainMenu(self)
    NSApplication.shared.mainMenu = menu

    do {
      try self.start()
    } catch OutletError.invalidArgument(let msg) {
      fatalError("OutletApp.start() failed: \(msg)")
    } catch {
      fatalError("OutletApp.start() failed with unexpected error: \(error)")
    }
  }

  // Menu/Toolbar actions
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼
  @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG [\(ID_APP)] validateMenuItem(): \(item)")
    }
    return self.globalActions.validateMenuItem(item)
  }

  func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG [\(ID_APP)] validateUserInterfaceItem(): \(item)")
    }
    return self.globalActions.validateUserInterfaceItem(item)
  }

  // TreeController registry
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Creates and starts a tree controller for the given tree, but does not load it.
  */
  public func buildController(_ tree: DisplayTree, canChangeRoot: Bool, allowsMultipleSelection: Bool) throws -> TreeController {
    let filterCriteria: FilterCriteria = try backend.getFilterCriteria(treeID: tree.treeID)
    let con = try TreeController(app: self, tree: tree, filterCriteria: filterCriteria, canChangeRoot: canChangeRoot, allowsMultipleSelection: allowsMultipleSelection)

    self.registerTreePanelController(con.treeID, con)
    try con.start()
    return con
  }

  func registerTreePanelController(_ treeID: TreeID, _ controller: TreeControllable) {
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

  func reregisterTreePanelController(oldTreeID: TreeID, newTreeID: TreeID, _ controller: TreeControllable) {
    self.tcDQ.sync {
      NSLog("DEBUG [\(oldTreeID)] Deregistering tree controller in frontend")
      self.treeControllerDict.removeValue(forKey: oldTreeID)
      NSLog("DEBUG [\(newTreeID)] Registering tree controller in frontend")
      self.treeControllerDict[newTreeID] = controller
    }
  }

  func getTreePanelController(_ treeID: TreeID) -> TreeControllable? {
    assert(DispatchQueue.isNotExecutingIn(self.tcDQ))

    var con: TreeControllable?
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
  private func displayError(_ msg: String, _ secondaryMsg: String) {
      self.tcDQ.sync {
        if self._backend!.isConnected {
          DispatchQueue.main.async {
            self.globalState.showAlert(title: msg, msg: secondaryMsg)
          }
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

    var currentSN: SPIDNodePair? = nil
    if sourceCon.tree.rootSN.node.treeType == .GDRIVE {
      currentSN = sourceCon.tree.rootSN
    }

    DispatchQueue.main.async {
      do {
        let tree: DisplayTree = try self.backend.createDisplayTreeForGDriveSelect(deviceUID: deviceUID)!
        let con = try self.buildController(tree, canChangeRoot: false, allowsMultipleSelection: false)

        if let gdriveRootChooser = self.gdriveRootChooserWindow {
          gdriveRootChooser.close()
        } else {
            self.gdriveRootChooserWindow = GDriveRootChooserWindow(self, con.treeID)
        }

        self.gdriveRootChooserWindow!.setController(con, initialSelection: currentSN, targetTreeID: treeID)
        try self.gdriveRootChooserWindow!.start()
      } catch {
        self.displayError("Error opening Google Drive root chooser window", "An unexpected error occurred: \(error)")
      }

    }
  }

  /**
   Display Merge Preview dialog
   */
  func openMergePreview(_ con: TreeControllable) {
    assert(DispatchQueue.isExecutingIn(.main))
    NSLog("DEBUG [\(ID_APP)] Opening MergePreview window")

    do {
      if let mergePreview = self.mergePreviewWindow {
        mergePreview.close()
      } else {
        self.mergePreviewWindow = MergePreviewWindow(self, treeID: con.treeID)
      }
      self.mergePreviewWindow!.setController(con)
      try self.mergePreviewWindow!.start()
    } catch {
      self.displayError("Error opening Merge Preview", "An unexpected error occurred: \(error)")
    }
  }

  /**
   Display Connection Problem dialog
   */
  func openConnectionProblemWindow() {
    assert(DispatchQueue.isExecutingIn(.main))

    self.globalState.reset()

    if self.connectionProblemWindow == nil {
      self.connectionProblemWindow = ConnectionProblemWindow(self, self._backend!.backendConnectionState)
    }

    NSLog("DEBUG [\(ID_APP)] Closing other windows besides ConnectionProblemWindow")
    // Close all other windows beside the Connection Problem window, if they exist
    self.mainWindow?.close()
    self.gdriveRootChooserWindow?.close()
    self.mergePreviewWindow?.close()

    // Open Connection Problem window
    NSLog("INFO  [\(ID_APP)] Showing ConnectionProblem window")
    do {
      try self.connectionProblemWindow!.start()
      NSLog("DEBUG [\(ID_APP)] Calling ConnectionProblem.showWindow()")
      self.connectionProblemWindow!.showWindow()
    } catch {
      NSLog("ERROR [\(ID_APP)] Failed to open ConnectionProblem window: \(error)")
      self.displayError("Failed to open Connecting window!", "An unexpected error occurred: \(error)")
    }
  }

  /**
   Display main window
   */
  private func openMainWindow() {
    NSLog("DEBUG [\(ID_APP)] Entered openMainWindow()")
    assert(DispatchQueue.isExecutingIn(.main))

    do {
      // TODO: eventually refactor this so that all state is stored in BE, and we only supply the tree_id when we request the state
      let treeLeft: DisplayTree = try self.backend.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try self.backend.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      let conLeft = try self.buildController(treeLeft, canChangeRoot: true, allowsMultipleSelection: true)
      let conRight = try self.buildController(treeRight, canChangeRoot: true, allowsMultipleSelection: true)

      // Seems like AppKit gets buggy when we try to use member variable to reference MainWindow. Try local variables as much as possible
      let mainWindow: MainWindow
      if let existingMainWindow = self.mainWindow {
        existingMainWindow.close()
        mainWindow = existingMainWindow
      } else {
        // FIXME: actually get the app to use these values
        var contentRect: NSRect? = nil
        do {
          contentRect = try self.loadMainWindowContentRectFromConfig(ID_MAIN_WINDOW)
        } catch {
          // recoverable error: just use defaults
          NSLog("ERROR [\(ID_MAIN_WINDOW)] Failed to load contentRect from config: \(error)")
        }
        mainWindow = MainWindow(self, contentRect)
      }

      self.tcDQ.sync {
        do {
          mainWindow.setControllers(left: conLeft, right: conRight)
          try mainWindow.start()
          DispatchQueue.main.async {
            NSLog("DEBUG [\(ID_APP)] Showing MainWindow")
            mainWindow.showWindow()
            self.mainWindow = mainWindow

            // Close Connection Problem window if it is open:
            self.connectionProblemWindow?.close()
          }
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
