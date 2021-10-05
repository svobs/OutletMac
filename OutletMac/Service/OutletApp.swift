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
  // Services:
  var dispatcher: SignalDispatcher { get }
  var backend: OutletBackend { get }
  var iconStore: IconStore { get }

  // State:
  var globalState: GlobalState { get }

  // TODO: remove these and replace with specialized DQs
  var serialQueue: DispatchQueue { get }
  func execAsync(_ workItem: @escaping NoArgVoidFunc)
  func execSync(_ workItem: @escaping NoArgVoidFunc)

  func validateMenuItem(_ item: NSMenuItem) -> Bool
  func diffTreesByContent()

  func grpcDidGoDown()
  func grpcDidGoUp()

  func confirmWithUserDialog(_ messageText: String, _ informativeText: String, okButtonText: String, cancelButtonText: String) -> Bool

  func buildController(_ tree: DisplayTree, canChangeRoot: Bool, allowsMultipleSelection: Bool) throws -> TreePanelController
  func registerTreePanelController(_ treeID: String, _ controller: TreePanelControllable)
  func deregisterTreePanelController(_ treeID: TreeID)
  func getTreePanelController(_ treeID: String) -> TreePanelControllable?

  func sendEnableUISignal(enable: Bool)

  func openGDriveRootChooser(_ deviceUID: UID, _ treeID: String)
}

class OutletMacApp: NSObject, NSApplicationDelegate, OutletApp {
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
  private var _backend: GRPCClientBackend?
  private var _iconStore: IconStore? = nil

  let serialQueue = DispatchQueue(label: "App-SerialQueue") // custom dispatch queues are serial by default

  private let tcDQ = DispatchQueue(label: "TreeControllerDict-SerialQueue")

  private var eventMonitor: GlobalEventMonitor? = nil

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

    let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .flagsChanged]
    self.eventMonitor =  GlobalEventMonitor(mask: eventMask, handler: self.onGlobalEvent)
    self.eventMonitor!.start()

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

    self.connectionProblemWindow = ConnectionProblemWindow(self, self._backend!.backendConnectionState)

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
        self.globalState.isBackendOpExecutorRunning = try self.backend.getOpExecutionPlayState()

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

  private func reportError(_ msg: String, _ secondaryMsg: String) {
    NSLog("ERROR Error from OutletApp: msg='\(msg)' secondaryMsg='\(secondaryMsg)'")
    self.displayError(msg, secondaryMsg)
  }

  private func reportException(_ title: String, _ error: Error) {
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
    NSLog("ERROR  Received error signal from '\(senderID)': msg='\(msg)' secondaryMsg='\(secondaryMsg)'")
    self.displayError(msg, secondaryMsg)
  }

  private func onOpExecutionPlayStateChanged(senderID: SenderID, propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("is_enabled")
    DispatchQueue.main.async {
      self.globalState.isBackendOpExecutorRunning = isEnabled
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
      let con = try self.buildController(newTree, canChangeRoot: false, allowsMultipleSelection: false)

      DispatchQueue.main.async {
        self.openMergePreview(con)
      }
    } catch {
      self.displayError("Failed to build merge tree", "\(error)")
    }
  }

  // NSApplicationDelegate methods
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

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

  // TODO: Deprecate!
  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
    self.serialQueue.async(execute: workItem)
  }

  // TODO: Deprecate!
  func execSync(_ workItem: @escaping NoArgVoidFunc) {
    assert(DispatchQueue.isNotExecutingIn(self.serialQueue))

    self.serialQueue.sync(execute: workItem)
  }

  // Menu/Toolbar actions
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼
  /**
    Called when a user clicks on a picker in the toolbar
   */
  @objc func toolbarPickerDidSelectItem(_ sender: Any) {
    NSLog("DEBUG [\(ID_APP)] toolbarPickerDidSelectItem() entered")

    if  let toolbarItemGroup = sender as? NSToolbarItemGroup {
      NSLog("DEBUG [\(ID_APP)] toolbarPickerDidSelectItem(): identifier = \(toolbarItemGroup.itemIdentifier)")

      if toolbarItemGroup.itemIdentifier == .dragModePicker {
        if let newValue = self.getValueFromIndex(toolbarItemGroup.selectedIndex, MainWindowToolbar.DRAG_MODE_LIST) {
          NSLog("INFO  [\(ID_APP)] User changed default drag operation: \(newValue) (index \(toolbarItemGroup.selectedIndex))")
          self.globalState.lastClickedDragOperation = newValue
        }

      } else if toolbarItemGroup.itemIdentifier == .dirConflictPolicyPicker {
        if let newValue = self.getValueFromIndex(toolbarItemGroup.selectedIndex, MainWindowToolbar.DIR_CONFLICT_POLICY_LIST) {
          NSLog("INFO  [\(ID_APP)] User changed dir conflict policy: \(newValue) (index \(toolbarItemGroup.selectedIndex))")
          self.globalState.currentDirConflictPolicy = newValue
        }

      } else if toolbarItemGroup.itemIdentifier == .fileConflictPolicyPicker {
        if let newValue = self.getValueFromIndex(toolbarItemGroup.selectedIndex, MainWindowToolbar.FILE_CONFLICT_POLICY_LIST) {
          NSLog("INFO  [\(ID_APP)] User changed file conflict policy: \(newValue) (index \(toolbarItemGroup.selectedIndex))")
          self.globalState.currentFileConflictPolicy = newValue
        }
      }
    }
  }

  private func getValueFromIndex<PickerValue>(_ selectedIndex: Int, _ pickerList: [PickerItem<PickerValue>]) -> PickerValue? {
    guard selectedIndex < pickerList.count else {
      reportError("Could not select option", "Invalid toolbar index: \(selectedIndex)")
      return nil
    }
    return pickerList[selectedIndex].value
  }

  /**
   Called by certain menu items, when they are drawn, to determine if they should be enabled.
    - Returns: true if the given menu item should be enabled, false if it should be disabled
   */
  @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
    guard let action = item.action else {
      return true
    }
    var isEnabled = false
    switch action {
    case AppMainMenu.DIFF_TREES_BY_CONTENT:
      if let mainWin = self.mainWindow, mainWin.isVisible && self.globalState.isUIEnabled && self.globalState.mode == .BROWSING {
        isEnabled = true
      }
    case AppMainMenu.MERGE_CHANGES:
      if let mainWin = self.mainWindow, mainWin.isVisible && self.globalState.isUIEnabled && self.globalState.mode == .DIFF {
        isEnabled = true
      }
    case AppMainMenu.CANCEL_DIFF:
      if let mainWin = self.mainWindow, mainWin.isVisible && self.globalState.isUIEnabled && self.globalState.mode == .DIFF {
        isEnabled = true
      }
    default:
      NSLog("ERROR [\(ID_APP)] validateMenuItem(): unrecognized action: \(action)")
      return false
    }
    NSLog("DEBUG [\(ID_APP)] validateMenuItem(): item \(action) enabled=\(isEnabled)")
    return isEnabled
  }

  /**
   Diff Trees By Content
   */
  @objc func diffTreesByContent() {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG [\(ID_APP)] Entered diffTreesByContent()")
    }

    guard let conLeft = self.getTreePanelController(ID_LEFT_TREE) else {
      self.reportError("Cannot diff", "Internal error: no controller for \(ID_LEFT_TREE) found!")
      return
    }
    guard let conRight = self.getTreePanelController(ID_RIGHT_TREE) else {
      self.reportError("Cannot diff", "Internal error: no controller for \(ID_RIGHT_TREE) found!")
      return
    }
    guard globalState.mode == .BROWSING else {
      self.reportError("Cannot start diff", "A diff is already in process, apparently (this is probably a bug)")
      return
    }

    // TODO: will this work if not loaded?
//    if conLeft.treeLoadState != .COMPLETELY_LOADED {
//      self.reportError("Cannot start diff", "Left tree is not finished loading")
//      return
//    }
//    if conRight.treeLoadState != .COMPLETELY_LOADED {
//      self.reportError("Cannot start diff", "Right tree is not finished loading")
//      return
//    }

    NSLog("DEBUG [\(ID_APP)] Sending request to BE to diff trees '\(conLeft.treeID)' & '\(conRight.treeID)'")

    // First disable UI
    self.sendEnableUISignal(enable: false)

    // Now ask BE to start the diff
    do {
      _ = try self.backend.startDiffTrees(treeIDLeft: conLeft.treeID, treeIDRight: conRight.treeID)
      //  We will be notified asynchronously when it is done/failed. If successful, the old tree_ids will be notified and supplied the new IDs
    } catch {
      NSLog("ERROR \(ID_APP)] Failed to start tree diff: \(error)")
      self.sendEnableUISignal(enable: true)
    }
  }

  /**
   Merge Changes
   */
  @objc func mergeDiffChanges() {
    guard self.globalState.mode == .DIFF else {
      self.reportError("Cannot merge changes", "A diff is not currently in progress")
      return
    }

    guard let conLeft = self.getTreePanelController(ID_LEFT_TREE) else {
      self.reportError("Cannot merge", "Internal error: no controller for \(ID_LEFT_TREE) found!")
      return
    }
    guard let conRight = self.getTreePanelController(ID_RIGHT_TREE) else {
      self.reportError("Cannot merge", "Internal error: no controller for \(ID_RIGHT_TREE) found!")
      return
    }
    do {
      let selectedChangeListLeft = try conLeft.generateCheckedRowList()
      let selectedChangeListRight = try conRight.generateCheckedRowList()

      let guidListLeft: [GUID] = selectedChangeListLeft.map({ $0.spid.guid })
      let guidListRight: [GUID] = selectedChangeListRight.map({ $0.spid.guid })
      if SUPER_DEBUG_ENABLED {
        NSLog("INFO  Selected changes (Left): [\(selectedChangeListLeft.map({ "\($0.spid)" }).joined(separator: "  "))]")
        NSLog("INFO  Selected changes (Right): [\(selectedChangeListRight.map({ "\($0.spid)" }).joined(separator: "  "))]")
      }

      self.sendEnableUISignal(enable: false)

      try self.backend.generateMergeTree(treeIDLeft: conLeft.treeID, treeIDRight: conRight.treeID,
              selectedChangeListLeft: guidListLeft, selectedChangeListRight: guidListRight)

    } catch {
      self.reportException("Failed to generate merge preview", error)
      self.sendEnableUISignal(enable: true)
    }
  }

  /**
   Cancel Diff
   */
  @objc func cancelDiff() {
    if self.globalState.mode != .DIFF {
      self.reportError("Cannot cancel diff", "A diff is not currently in progress")
      return
    }
    NSLog("DEBUG CancelDiff activated! Sending signal: '\(Signal.EXIT_DIFF_MODE)'")
    self.dispatcher.sendSignal(signal: .EXIT_DIFF_MODE, senderID: ID_APP)
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
  private func displayError(_ msg: String, _ secondaryMsg: String) {
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
  func openMergePreview(_ con: TreePanelControllable) {
    assert(DispatchQueue.isExecutingIn(.main))

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

  /**
   Display Connection Problem dialog
   */
  func openConnectionProblemWindow() {
    assert(DispatchQueue.isExecutingIn(.main))

    self.globalState.reset()

    NSLog("DEBUG [\(ID_APP)] Closing other windows besides ConnectionProblemWindow")
    // Close all other windows beside the Connection Problem window, if they exist
    self.mainWindow?.close()
    self.rootChooserWindow?.close()
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
        self.mainWindow?.close()
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
