//
//  GRPCClientBackend.swift
//  
//
//  Created by Matthew Svoboda on 2021-01-11.
//

import Foundation
import GRPC
import Logging
import NIO

/**
 CLASS GRPCClientBackend

 Thin gRPC client to the backend service
 */
class GRPCClientBackend: OutletBackend {
  var stub: Outlet_Backend_Agent_Grpc_Generated_OutletClient
  let app: OutletApp
  let bonjourService = BonjourService()
  let backendConnectionState: BackendConnectionState
  let dispatchListener: DispatchListener
  var grpcConverter = GRPCConverter()
  var nodeIdentifierFactory = NodeIdentifierFactory()
  private var signalReceiverThread: Thread?
  private var wasShutdown = false
  private var useFixedAddress: Bool = false
  private var fixedHost: String? = nil
  private var fixedPort: Int? = nil
  private var tryLocalHostFirst = true

  private let dqGRPC = DispatchQueue(label: "GRPC-SerialQueue") // custom dispatch queues are serial by default

  var isConnected: Bool {
    get {
      return self.backendConnectionState.isConnected
    }
  }

  init(_ app: OutletApp, useFixedAddress: Bool = false, fixedHost: String? = nil, fixedPort: Int? = nil) {
    self.app = app
    self.useFixedAddress = useFixedAddress
    self.fixedHost = fixedHost
    self.fixedPort = fixedPort
    self.dispatchListener = app.dispatcher.createListener(ID_BACKEND_CLIENT)
    self.backendConnectionState = BackendConnectionState(host: DEFAULT_GRPC_SERVER_ADDRESS, port: DEFAULT_GRPC_SERVER_PORT)
    self.stub = GRPCClientBackend.makeClientStub(backendConnectionState.host, backendConnectionState.port)
  }

  func start() throws {
    NSLog("DEBUG Starting GRPCClientBackend...")
    grpcConverter.backend = self
    nodeIdentifierFactory.backend = self

    // Forward the following Dispatcher signals across gRPC:
    connectAndForwardSignal(.PAUSE_OP_EXECUTION)
    connectAndForwardSignal(.RESUME_OP_EXECUTION)
    connectAndForwardSignal(.COMPLETE_MERGE)
    connectAndForwardSignal(.DEREGISTER_DISPLAY_TREE)
    connectAndForwardSignal(.EXIT_DIFF_MODE)

    connectAndForwardBatchFailedSignal()

    // This thread will also handle the discovery:
    let thread = Thread(target: self, selector: #selector(self.runSignalReceiverThread), object: nil)
    self.signalReceiverThread = thread
    thread.start()
  }
  
  func shutdown() throws {
    if self.wasShutdown {
      return
    }
    if let thread = self.signalReceiverThread {
      thread.cancel()
      self.signalReceiverThread = nil
    }
    try self.stub.channel.close().wait()
    self.wasShutdown = true
  }

  private static func makeClientStub(_ host: String, _ port: Int) -> Outlet_Backend_Agent_Grpc_Generated_OutletClient {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let channel = ClientConnection.insecure(group: group)
            .withConnectionTimeout(minimum: TimeAmount.seconds(GRPC_CONNECTION_TIMEOUT_SEC))
            .withConnectionBackoff(retries: ConnectionBackoff.Retries.upTo(GRPC_MAX_CONNECTION_RETRIES))
            .connect(host: host, port: port)

    return Outlet_Backend_Agent_Grpc_Generated_OutletClient(channel: channel)
  }

  func closeChannel() {
    do {
      NSLog("DEBUG Closing gRPC channel")
      try self.stub.channel.close().wait()
    } catch {
      NSLog("ERROR While closing client gRPC channel: \(error)")
    }
  }

  func replaceStub() {
    self.closeChannel()

    NSLog("DEBUG Making new gRPC client stub...")
    self.stub = GRPCClientBackend.makeClientStub(self.backendConnectionState.host, self.backendConnectionState.port)
  }

  @objc func runSignalReceiverThread() {
    NSLog("DEBUG [SignalReceiverThread] Starting thread")

    while !self.wasShutdown {
      self.locateBackendServer(onSuccess: self.openGRPCConnection)
    }
    NSLog("DEBUG [SignalReceiverThread] Thread shutting down")
    self.bonjourService.stopDiscovery()
  }

  private func locateBackendServer(onSuccess onSuccessFunc: () -> ()) {
    NSLog("DEBUG [SignalReceiverThread] Locating backend server (useFixedAddress=\(useFixedAddress))")

    let group = DispatchGroup()
    group.enter()
    var discoverySucceeded: Bool = false
    if useFixedAddress {
      assert(fixedHost != nil && fixedPort != nil)
      DispatchQueue.main.async {
        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG Entering new DispatchGroup")
        }
        self.backendConnectionState.host = self.fixedHost!
        self.backendConnectionState.port = self.fixedPort!
        discoverySucceeded = true

        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG Leaving DispatchGroup")
        }
        group.leave()
      }
    } else {
      // Occasionally both success & failure handlers will be called in quick succession. In this case, we need to make sure we don't
      // call group.leave() twice for the same group.enter(), cuz that will crash us:
      var leftGroup = false

      // IMPORTANT: this needs to be kicked off on the main thread or else it will silently fail to discover services!
      DispatchQueue.main.async {
        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG Entering new DispatchGroup")
        }

        // Do discovery all over again, in case the address has changed:
        self.bonjourService.startDiscovery(onSuccess: { ipPort in
          DispatchQueue.main.async {
            if leftGroup {
              NSLog("DEBUG Already left DispatchGroup; ignoring success handler call")
              return
            }
            defer {
              if SUPER_DEBUG_ENABLED {
                NSLog("DEBUG Leaving DispatchGroup")
              }
              leftGroup = true
              group.leave()
            }
            self.tryLocalHostFirst = true
            self.backendConnectionState.host = ipPort.ip
            self.backendConnectionState.port = ipPort.port

            NSLog("INFO  Found server via Bonjour: \(self.backendConnectionState.host):\(self.backendConnectionState.port)")
            discoverySucceeded = true
          }

        }, onError: { error in
          DispatchQueue.main.async {
            if leftGroup {
              NSLog("DEBUG Already left DispatchGroup; ignoring error handler call")
              return
            }

            NSLog("ERROR Failed to find server via BonjourService: \(error)")

            leftGroup = true
            group.leave()
          }
        })
      }
      // fall through
    }

    // Wait until success or failure
    NSLog("DEBUG [SignalReceiverThread] Waiting for BonjourService service discovery (timeout=\(BONJOUR_SERVICE_DISCOVERY_TIMEOUT_SEC)s)...")
    if group.wait(timeout: .now() + BONJOUR_SERVICE_DISCOVERY_TIMEOUT_SEC) == .timedOut {
      NSLog("INFO  [SignalReceiverThread] Service discovery timed out. Will retry signal stream in \(SIGNAL_THREAD_SLEEP_PERIOD_SEC) sec...")
    } else {
      if discoverySucceeded {
        NSLog("DEBUG [SignalReceiverThread] Discovery succeeded. Connecting to server")
        onSuccessFunc()
      } else {
        NSLog("INFO  [SignalReceiverThread] Discovery failed")
      }

      NSLog("INFO  [SignalReceiverThread] Will retry signal stream in \(SIGNAL_THREAD_SLEEP_PERIOD_SEC) sec...")
    }

    Thread.sleep(forTimeInterval: SIGNAL_THREAD_SLEEP_PERIOD_SEC)
    NSLog("DEBUG [SignalReceiverThread] Looping (count: \(self.backendConnectionState.conecutiveStreamFailCount))")

    DispatchQueue.main.sync {
      self.backendConnectionState.conecutiveStreamFailCount += 1
    }
  }

  // Signals
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func connectAndForwardBatchFailedSignal() {
    let signal =  Signal.HANDLE_BATCH_FAILED
    self.dispatchListener.subscribe(signal: signal) { (senderID, propDict) in
      var signalMsg = self.createSignalMsg(signal, senderID)
      signalMsg.handleBatchFailed.batchUid = try propDict.getUInt32("batch_uid")
      signalMsg.handleBatchFailed.errorHandlingStrategy = (try propDict.get("error_handling_strategy") as! ErrorHandlingStrategy).rawValue
      _ = self.stub.send_signal(signalMsg)
    }
  }

  private func connectAndForwardSignal(_ signal: Signal) {
    self.dispatchListener.subscribe(signal: signal) { (senderID, propDict) in
      self.sendSignalToServer(signal, senderID)
    }
  }

  private func sendSignalToServer(_ signal: Signal, _ senderID: SenderID, _ propDict: PropDict? = nil) {
    let signalMsg = self.createSignalMsg(signal, senderID)
    _ = self.stub.send_signal(signalMsg)
  }

  private func createSignalMsg(_ signal: Signal, _ senderID: SenderID) -> Outlet_Backend_Agent_Grpc_Generated_SignalMsg {
    var signalMsg = Outlet_Backend_Agent_Grpc_Generated_SignalMsg()
    signalMsg.sigInt = signal.rawValue
    signalMsg.sender = senderID
    return signalMsg
  }

  func openGRPCConnection() {
    let host = self.backendConnectionState.host
    // FiXME: this "tryLocalHostFirst" is a junk solution - need to detect server name for localhost and compare IPs instead
    if self.tryLocalHostFirst {
      NSLog("INFO  Attempting connect with localhost, port \(self.backendConnectionState.port)")
      DispatchQueue.main.sync {
        self.backendConnectionState.host = "127.0.0.1"
      }
      self.receiveServerSignals()
    }

    DispatchQueue.main.sync {
      self.backendConnectionState.host = host
    }
    NSLog("INFO  Attempting connect with \(self.backendConnectionState.host):\(self.backendConnectionState.port)")
    self.receiveServerSignals()
  }

  /**
   Receives signals from the gRPC server and forwards them throughout the app via the app's Dispatcher.
   This will return only if there's an error (usually connection lost):
   */
  func receiveServerSignals() {
    // It seems that once the channel fails to connect, it will never succeed. Replace the whole object
    self.replaceStub()

    NSLog("DEBUG Subscribing to server signals...")
    NSLog("DEBUG receiveServerSignals(): Current queue: '\(DispatchQueue.currentQueueLabel ?? "nil")'")

    let request = Outlet_Backend_Agent_Grpc_Generated_Subscribe_Request()
    let call = self.stub.subscribe_to_signals(request) { signalGRPC in
      // This is fired each time we get a new signal (implicitly this means the connection is back up)

      if TRACE_ENABLED {
        NSLog("DEBUG Got new signal: \(signalGRPC.sigInt)")
      }
      self.grpcConnectionRestored()
      do {
        try self.relaySignalLocally(signalGRPC)
      } catch {
        guard let signal = Signal(rawValue: signalGRPC.sigInt) else {
          NSLog("ERROR Could not resolve Signal from int value: \(signalGRPC.sigInt)")
          NSLog("ERROR While relaying received signal: \(error)")
          return
        }
        NSLog("ERROR While relaying received signal \(signal): \(error)")
        self.reportError("While relaying received signal \(signal)", "\(error)")
      }
    }

    /*
     NOTE: this is called when the request returns. But we are using the open request as a stream with no end, so if we get a request returning
     it always indicates either a server shutdown or a failure of some kind.
     */
    call.status.whenSuccess { status in
      if status.code == .ok {
        // this should only happen if the server needs to restart.
        NSLog("INFO  ReceiveSignals(): Server closed signal subscription")
      } else if status.code == .unavailable {
        NSLog("IMFO  ReceiveSignals(): Server unavailable (status: \(status)) - closing connection to \(self.backendConnectionState.host):\(self.backendConnectionState.port)")
      } else {
        NSLog("ERROR ReceiveSignals(): received error: \(status)")
      }
      self.app.grpcDidGoDown()
    }

    // Wait for the call to end. It will only end if an error occurred (see call.status.whenSuccess above)
    do {
      _ = try call.status.wait()
    } catch {
      NSLog("ERROR ReceiveSignals(): signal receive call ended with exception: \(error)")
    }
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG receiveServerSignals() returning")
    }
  }

  private func relaySignalLocally(_ signalGRPC: Outlet_Backend_Agent_Grpc_Generated_SignalMsg) throws {
    guard let signal = Signal(rawValue: signalGRPC.sigInt) else {
      fatalError("Could not resolve Signal from int value: \(signalGRPC.sigInt)")
    }
    NSLog("DEBUG GRPCClient: got signal from backend via gRPC: \(signal) with sender: \(signalGRPC.sender)")
    var argDict: [String: Any] = [:]

    switch signal {
    case .WELCOME:
        // Do not forward to clients. Welcome msg is used just for its ping functionality
        return
      case .DISPLAY_TREE_CHANGED, .GENERATE_MERGE_TREE_DONE:
        let displayTreeUiState = try self.grpcConverter.displayTreeUiStateFromGRPC(signalGRPC.displayTreeUiState)
        let tree: DisplayTree = displayTreeUiState.toDisplayTree(backend: self)
        argDict["tree"] = tree
      case .DIFF_TREES_DONE, .DIFF_TREES_CANCELLED:
        let displayTreeUiStateL = try self.grpcConverter.displayTreeUiStateFromGRPC(signalGRPC.dualDisplayTree.leftTree)
        let treeL: DisplayTree = displayTreeUiStateL.toDisplayTree(backend: self)
        argDict["tree_left"] = treeL
        let displayTreeUiStateR = try self.grpcConverter.displayTreeUiStateFromGRPC(signalGRPC.dualDisplayTree.rightTree)
        let treeR: DisplayTree = displayTreeUiStateR.toDisplayTree(backend: self)
        argDict["tree_right"] = treeR
      case .OP_EXECUTION_PLAY_STATE_CHANGED:
        argDict["is_enabled"] = signalGRPC.playState.isEnabled
      case .TOGGLE_UI_ENABLEMENT:
        argDict["enable"] = signalGRPC.uiEnablement.enable
      case .SET_SELECTED_ROWS:
        var guidSet = Set<GUID>()
        for guid in signalGRPC.guidSet.guidSet {
          guidSet.insert(guid)
        }
        argDict["selected_rows"] = guidSet
      case .ERROR_OCCURRED:
        argDict["msg"] = signalGRPC.errorOccurred.msg
        argDict["secondary_msg"] = signalGRPC.errorOccurred.secondaryMsg
      case .NODE_UPSERTED, .NODE_REMOVED:
        argDict["sn"] = try self.grpcConverter.snFromGRPC(signalGRPC.sn)
      case .SUBTREE_NODES_CHANGED:
        argDict["subtree_root_spid"] = try self.grpcConverter.spidFromGRPC(spidGRPC: signalGRPC.subtree.subtreeRootSpid)
        argDict["upserted_sn_list"] = try self.grpcConverter.snListFromGRPC(signalGRPC.subtree.upsertedSnList)
        argDict["removed_sn_list"] = try self.grpcConverter.snListFromGRPC(signalGRPC.subtree.removedSnList)
      case .TREE_LOAD_STATE_UPDATED:
        argDict["tree_load_state"] = TreeLoadState(rawValue: signalGRPC.treeLoadUpdate.loadStateInt)
        try self.convertStatsAndStatus(statsUpdate: signalGRPC.treeLoadUpdate.statsUpdate, argDict: &argDict)
      case .DOWNLOAD_FROM_GDRIVE_DONE:
        argDict["filename"] = signalGRPC.downloadMsg.filename
      case .STATS_UPDATED:
        try self.convertStatsAndStatus(statsUpdate: signalGRPC.statsUpdate, argDict: &argDict)
      case .DEVICE_UPSERTED:
        argDict["device"] = try self.grpcConverter.deviceFromGRPC(signalGRPC.device)
      case .BATCH_FAILED:
        argDict["batch_uid"] = signalGRPC.batchFailed.batchUid
        argDict["msg"] = signalGRPC.batchFailed.msg
        argDict["secondary_msg"] = signalGRPC.batchFailed.secondaryMsg
      default:
        break
    }
    argDict["signal"] = signal

    app.dispatcher.sendSignal(signal: signal, senderID: signalGRPC.sender, argDict)
  }

  private func convertStatsAndStatus(statsUpdate: Outlet_Backend_Agent_Grpc_Generated_StatsUpdate, argDict: inout [String: Any]) throws {
    argDict["status_msg"] = statsUpdate.statusMsg

    var dirStatsByUidDict: [UID:DirectoryStats] = [:]
    for dirMetaUpdate in statsUpdate.dirMetaByUidList {
      dirStatsByUidDict[dirMetaUpdate.uid] = try self.grpcConverter.dirMetaFromGRPC(dirMetaUpdate.dirMeta)
    }
    argDict["dir_stats_dict_by_uid"] = dirStatsByUidDict

    var dirStatsByGuidDict: [GUID:DirectoryStats] = [:]
    for dirMetaUpdate in statsUpdate.dirMetaByGuidList {
      dirStatsByGuidDict[dirMetaUpdate.guid] = try self.grpcConverter.dirMetaFromGRPC(dirMetaUpdate.dirMeta)
    }
    argDict["dir_stats_dict_by_guid"] = dirStatsByGuidDict
  }

  /**
   Convenience function. Sends a given error to the Dispatcher for reporting elsewhere.
   */
  private func reportError(_ msg: String, _ secondaryMsg: String) {
    var argDict: [String: Any] = [:]
    argDict["msg"] = msg
    argDict["secondary_msg"] = secondaryMsg
    app.dispatcher.sendSignal(signal: .ERROR_OCCURRED, senderID: ID_BACKEND_CLIENT, argDict)
  }

  // Remaining RPCs
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func requestDisplayTree(_ request: DisplayTreeRequest) throws -> DisplayTree? {
    NSLog("DEBUG [\(request.treeID)] Requesting DisplayTree for params: \(request)")
    var grpcRequest = Outlet_Backend_Agent_Grpc_Generated_RequestDisplayTree_Request()
    grpcRequest.isStartup = request.isStartup
    grpcRequest.treeID = request.treeID
    grpcRequest.userPath = request.userPath ?? ""
    grpcRequest.deviceUid = request.deviceUID ?? 0
    grpcRequest.returnAsync = request.returnAsync
    grpcRequest.treeDisplayMode = request.treeDisplayMode.rawValue
    
    if let spid = request.spid {
      grpcRequest.spid = try self.grpcConverter.nodeIdentifierToGRPC(spid)
    }

    let response = try self.callAndTranslateErrors(self.stub.request_display_tree(grpcRequest), "requestDisplayTree")
    if (response.hasDisplayTreeUiState) {
      let state: DisplayTreeUiState = try self.grpcConverter.displayTreeUiStateFromGRPC(response.displayTreeUiState)
      NSLog("DEBUG [\(request.treeID)] Got state: \(state)")
      return state.toDisplayTree(backend: self)
    } else {
      return nil
    }
  }
  
  func getNodeForUID(uid: UID, deviceUID: UID) throws -> Node? {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetNodeForUid_Request()
    request.uid = uid
    request.deviceUid = deviceUID
    let response = try self.callAndTranslateErrors(self.stub.get_node_for_uid(request), "getNodeForUID")

    if (response.hasNode) {
      return try self.grpcConverter.nodeFromGRPC(response.node)
    } else {
      return nil
    }
  }

  func nextUID() throws -> UID {
    let request = Outlet_Backend_Agent_Grpc_Generated_GetNextUid_Request()
    let response = try self.callAndTranslateErrors(self.stub.get_next_uid(request), "nextUID")

    return response.uid
  }
  
  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID? {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetUidForLocalPath_Request()
    request.fullPath = fullPath
    if let uidSuggestion = uidSuggestion {
      request.uidSuggestion = uidSuggestion
    }
    let response = try self.callAndTranslateErrors(self.stub.get_uid_for_local_path(request), "getUIDForLocalPath")

    return response.uid
  }

  func getSNFor(nodeUID: UID, deviceUID: UID, fullPath: String) throws -> SPIDNodePair? {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetSnFor_Request()
    request.nodeUid = nodeUID
    request.deviceUid = deviceUID
    request.fullPath = fullPath
    let response = try self.callAndTranslateErrors(self.stub.get_sn_for(request), "getSNFor")

    if response.hasSn {
      return try self.grpcConverter.snFromGRPC(response.sn)
    }
    return nil
  }
  
  func startSubtreeLoad(treeID: TreeID) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_StartSubtreeLoad_Request()
    request.treeID = treeID
    let _ = try self.callAndTranslateErrors(self.stub.start_subtree_load(request), "startSubtreeLoad")
  }
  
  func getOpExecutionPlayState() throws -> Bool {
    let request = Outlet_Backend_Agent_Grpc_Generated_GetOpExecPlayState_Request()
    let response = try self.callAndTranslateErrors(self.stub.get_op_exec_play_state(request), "getOpExecutionPlayState")

    return response.isEnabled
  }

  func getDeviceList() throws -> [Device] {
    var deviceList: [Device] = []
    let request = Outlet_Backend_Agent_Grpc_Generated_GetDeviceList_Request()
    let response = try self.callAndTranslateErrors(self.stub.get_device_list(request), "getDeviceList")

    for deviceGRPC in response.deviceList {
      deviceList.append(try self.grpcConverter.deviceFromGRPC(deviceGRPC))
    }
    return deviceList
  }

  func getChildList(parentSPID: SPID, treeID: TreeID?, isExpandingParent: Bool = false, maxResults: UInt32?) throws -> [SPIDNodePair] {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetChildList_Request()
    if let treeID = treeID {
      request.treeID = treeID
    }
    request.parentSpid = try self.grpcConverter.nodeIdentifierToGRPC(parentSPID)
    request.isExpandingParent = isExpandingParent
    request.maxResults = maxResults ?? 0

    let response = try self.callAndTranslateErrors(self.stub.get_child_list_for_spid(request), "getChildList")

    if response.resultExceededCount > 0 {
      assert (maxResults != nil && maxResults! > 0)
      throw OutletError.maxResultsExceeded(actualCount: response.resultExceededCount)
    }

    return try self.grpcConverter.snListFromGRPC(response.childList)
  }

  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [SPIDNodePair] {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetAncestorList_Request()
    request.stopAtPath = stopAtPath ?? ""
    request.spid = try self.grpcConverter.nodeIdentifierToGRPC(spid)

    let response = try self.callAndTranslateErrors(self.stub.get_ancestor_list_for_spid(request), "getAncestorList")
    return try self.grpcConverter.snListFromGRPC(response.ancestorList)
  }

  func getRowsOfInterest(treeID: TreeID) throws -> RowsOfInterest {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetRowsOfInterest_Request()
    request.treeID = treeID

    let response = try self.callAndTranslateErrors(self.stub.get_rows_of_interest(request), "getRowsOfInterest")

    let rows = RowsOfInterest()
    for guid in response.expandedRowGuidSet {
      rows.expanded.insert(guid)
    }
    for guid in response.selectedRowGuidSet {
      rows.selected.insert(guid)
    }
    return rows
  }

  func setSelectedRowSet(_ selected: Set<GUID>, _ treeID: TreeID) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_SetSelectedRowSet_Request()
    for guid in selected {
      request.selectedRowGuidSet.append(guid)
    }
    request.treeID = treeID

    let _ = try self.callAndTranslateErrors(self.stub.set_selected_row_set(request), "setSelectedRowSet")
  }

  func removeExpandedRow(_ rowGUID: GUID, _ treeID: TreeID) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_RemoveExpandedRow_Request()
    request.rowGuid = rowGUID
    request.treeID = treeID

    let _ = try self.callAndTranslateErrors(self.stub.remove_expanded_row(request), "removeExpandedRow")
  }

  func getContextMenu(treeID: TreeID, _ identifierList: [NodeIdentifier]) throws -> [ContextMenuItem] {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetContextMenu_Request()
    request.treeID = treeID
    for nodeIdentifier in identifierList {
      request.identifierList.append(try self.grpcConverter.nodeIdentifierToGRPC(nodeIdentifier))
    }

    let response = try self.callAndTranslateErrors(self.stub.get_context_menu(request), "getContextMenu")
    return try self.grpcConverter.menuItemListFromGRPC(response.menuItemList)
  }

  func createDisplayTreeForGDriveSelect(deviceUID: UID) throws -> DisplayTree? {
    let spid = self.nodeIdentifierFactory.getRootConstantGDriveSPID(deviceUID)
    let request = DisplayTreeRequest(treeID: ID_GDRIVE_DIR_SELECT, returnAsync: false, spid: spid, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }
  
  func createDisplayTreeFromConfig(treeID: TreeID, isStartup: Bool = false) throws -> DisplayTree? {
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: false, isStartup: isStartup, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }

  func createDisplayTreeFromSPID(treeID: TreeID, spid: SinglePathNodeIdentifier) throws -> DisplayTree? {
    // Note: this shouldn't actually return anything, as returnAsync==true
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: true, spid: spid, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }
  
  func createDisplayTreeFromUserPath(treeID: TreeID, userPath: String, deviceUID: UID) throws -> DisplayTree? {
    // Note: this shouldn't actually return anything, as returnAsync==true
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: true, userPath: userPath, deviceUID: deviceUID, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }

  func createExistingDisplayTree(treeID: TreeID, treeDisplayMode: TreeDisplayMode) throws -> DisplayTree? {
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: false, treeDisplayMode: treeDisplayMode)
    return try self.requestDisplayTree(request)
  }
  
  /**
   Notifies the backend that the tree was requested, and returns a display tree object, which the backend will also send via
   notification (unless is_startup==True, in which case no notification will be sent). Also is_startup helps determine whether
   to load it immediately.
   
   The DisplayTree object is immediately created and returned even if the tree has not finished loading on the backend. The backend
   will send a notification if/when it has finished loading.
   */
  func requestDisplayTree(request: DisplayTreeRequest) throws -> DisplayTree? {
    var requestGRPC = Outlet_Backend_Agent_Grpc_Generated_RequestDisplayTree_Request()
    requestGRPC.isStartup = request.isStartup
    requestGRPC.treeID = request.treeID
    requestGRPC.returnAsync = request.returnAsync
    requestGRPC.userPath = request.userPath ?? ""
    if let spid = request.spid {
      requestGRPC.spid = try self.grpcConverter.nodeIdentifierToGRPC(spid)
    }
    requestGRPC.treeDisplayMode = request.treeDisplayMode.rawValue

    let response = try self.callAndTranslateErrors(self.stub.request_display_tree(requestGRPC), "requestDisplayTree")

    if response.hasDisplayTreeUiState {
      let state = try self.grpcConverter.displayTreeUiStateFromGRPC(response.displayTreeUiState)
      let tree = state.toDisplayTree(backend: self)
      NSLog("Returning DisplayTree: \(tree)")
      return tree
    } else {
      NSLog("Returning DisplayTree==null")
      return nil
    }
  }

  func dropDraggedNodes(srcTreeID: TreeID, srcGUIDList: [GUID], isInto: Bool, dstTreeID: TreeID, dstGUID: GUID, dragOperation: DragOperation, dirConflictPolicy: DirConflictPolicy, fileConflictPolicy: FileConflictPolicy)
      throws -> Bool {
    var request = Outlet_Backend_Agent_Grpc_Generated_DragDrop_Request()
    request.srcTreeID = srcTreeID
    request.dstTreeID = dstTreeID
    request.dstGuid = dstGUID
    for srcGUID in srcGUIDList {
      request.srcGuidList.append(srcGUID)
    }
    request.isInto = isInto
    request.dragOperation = dragOperation.rawValue
    request.dirConflictPolicy = dirConflictPolicy.rawValue
    request.fileConflictPolicy = fileConflictPolicy.rawValue

    let response = try self.callAndTranslateErrors(self.stub.drop_dragged_nodes(request), "dropDraggedNodes")
    return response.isAccepted
  }
  
  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs {
    var request = Outlet_Backend_Agent_Grpc_Generated_StartDiffTrees_Request()
    request.treeIDLeft = treeIDLeft
    request.treeIDRight = treeIDRight

    let response = try self.callAndTranslateErrors(self.stub.start_diff_trees(request), "startDiffTrees")
    let treeIDs = DiffResultTreeIDs(left: response.treeIDLeft, right: response.treeIDRight)
    return treeIDs
  }
  
  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [GUID], selectedChangeListRight: [GUID]) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_GenerateMergeTree_Request()
    request.treeIDLeft = treeIDLeft
    request.treeIDRight = treeIDRight
    for guid in selectedChangeListLeft {
      request.changeListLeft.append(guid)
    }
    for guid in selectedChangeListRight {
      request.changeListRight.append(guid)
    }

    let _ = try self.callAndTranslateErrors(self.stub.generate_merge_tree(request), "generateMergeTree")
  }
  
  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: TreeID) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_RefreshSubtree_Request()
    request.nodeIdentifier = try self.grpcConverter.nodeIdentifierToGRPC(nodeIdentifier)
    request.treeID = treeID
    let _ = try self.callAndTranslateErrors(self.stub.refresh_subtree(request), "enqueueRefreshSubtreeTask")
  }

  func getLastPendingOp(deviceUID: UID, nodeUID: UID) throws -> UserOp? {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetLastPendingOp_Request()
    request.deviceUid = deviceUID
    request.nodeUid = nodeUID

    let response = try self.callAndTranslateErrors(self.stub.get_last_pending_op_for_node(request), "getLastPendingOp")
      
    if !response.hasUserOp {
      return nil
    }
    let srcNode = try self.grpcConverter.nodeFromGRPC(response.userOp.srcNode)
    let dstNode: Node?
    if response.userOp.hasDstNode {
      dstNode = try self.grpcConverter.nodeFromGRPC(response.userOp.dstNode)
    } else {
      dstNode = nil
    }
    guard let opType = UserOpType(rawValue: response.userOp.opType) else {
      fatalError("Could not resolve UserOpType from int value: \(response.userOp.opType)")
    }

    return UserOp(opUID: response.userOp.opUid, batchUID: response.userOp.batchUid, opType: opType, srcNode: srcNode, dstNode: dstNode)
  }
  
  func downloadFileFromGDrive(deviceUID: UID, nodeUID: UID, requestorID: String) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_DownloadFromGDrive_Request()
    request.deviceUid = deviceUID
    request.nodeUid = nodeUID
    request.requestorID = requestorID
    let _ = try self.callAndTranslateErrors(self.stub.download_file_from_gdrive(request), "downloadFileFromGDrive")
  }
  
  func deleteSubtree(deviceUID: UID, nodeUIDList: [UID]) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_DeleteSubtree_Request()
    request.deviceUid = deviceUID
    request.nodeUidList = nodeUIDList
    let _ = try self.callAndTranslateErrors(self.stub.delete_subtree(request), "deleteSubtree")
  }
  
  func getFilterCriteria(treeID: TreeID) throws -> FilterCriteria {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetFilter_Request()
    request.treeID = treeID
    let response = try self.callAndTranslateErrors(self.stub.get_filter(request), "getFilterCriteria")
    if response.hasFilterCriteria {
      let filterCriteria = try self.grpcConverter.filterCriteriaFromGRPC(response.filterCriteria)
      NSLog("DEBUG [\(treeID)] FilterCriteria from gRPC: \(filterCriteria)")
      return filterCriteria
    } else {
      throw OutletError.invalidState("No FilterCriteria (probably unknown tree) for tree: \(treeID)")
    }
  }
  
  func updateFilterCriteria(treeID: TreeID, filterCriteria: FilterCriteria) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_UpdateFilter_Request()
    request.treeID = treeID
    request.filterCriteria = try self.grpcConverter.filterCriteriaToGRPC(filterCriteria)
    let _ = try self.callAndTranslateErrors(self.stub.update_filter(request), "updateFilterCriteria")
  }

  func getConfig(_ configKey: String, defaultVal: String? = nil) throws -> String {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetConfig_Request()
    request.configKeyList.append(configKey)

    let response = try self.callAndTranslateErrors(self.stub.get_config(request), "getConfig")
    if response.configList.count != 1 {
      throw OutletError.invalidState("RPC 'getConfig' failed: got more than one value for config list")
    } else {
      assert(response.configList[0].key == configKey, "getConfig(): response key (\(response.configList[0].key)) != expected (\(configKey))")
      let val = response.configList[0].val
      // remember, gRPC will never return nil; it will return empty string
      if val == "" {
        if let defaultVal = defaultVal {
          return defaultVal
        } else {
          throw OutletError.invalidState("RPC 'getConfig' failed: no default value supplied but got nil value for key '\(configKey)'")
        }
      } else {
        return val
      }
    }
  }

  func getUInt32Config(_ configKey: String, defaultVal: UInt32? = nil) throws -> UInt32 {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG getUInt32Config entered")
    }
    let defaultValStr: String?
    if let defaultVal = defaultVal {
      defaultValStr = String(defaultVal)
    } else {
      defaultValStr = nil
    }
    let configVal: String = try self.getConfig(configKey, defaultVal: defaultValStr)
    guard let configValUInt32 = UInt32(configVal) else {
      throw OutletError.invalidState("Failed to parse value \"\(configVal)\" as UInt32 for key \"\(configKey)\"")
    }

    NSLog("DEBUG getUInt32Config returning: \(configValUInt32)")
    return configValUInt32
  }

  func getIntConfig(_ configKey: String, defaultVal: Int? = nil) throws -> Int {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG getIntConfig entered")
    }
    let defaultValStr: String?
    if let defaultVal = defaultVal {
      defaultValStr = String(defaultVal)
    } else {
      defaultValStr = nil
    }
    let configVal: String = try self.getConfig(configKey, defaultVal: defaultValStr)
    guard let configValInt = Int(configVal) else {
      throw OutletError.invalidState("Failed to parse value \"\(configVal)\" as Int for key \"\(configKey)\"")
    }

    NSLog("DEBUG getIntConfig returning: \(configValInt)")
    return configValInt
  }

  func getBoolConfig(_ configKey: String, defaultVal: Bool? = nil) throws -> Bool {
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG getBoolConfig entered")
    }
    let defaultValStr: String?
    if let defaultVal = defaultVal {
      defaultValStr = String(defaultVal)
    } else {
      defaultValStr = nil
    }
    let configVal: String = try self.getConfig(configKey, defaultVal: defaultValStr)
    guard let configValBool = Bool(configVal.lowercased()) else {
      throw OutletError.invalidState("Failed to parse value \"\(configVal)\" as Bool for key \"\(configKey)\"")
    }
    NSLog("DEBUG getBoolConfig returning: \(configValBool)")
    return configValBool
  }

  func putConfig(_ configKey: String, _ configVal: String) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_PutConfig_Request()
    var configEntry = Outlet_Backend_Agent_Grpc_Generated_ConfigEntry()
    configEntry.key = configKey
    configEntry.val = configVal
    request.configList.append(configEntry)
    let _ = try self.callAndTranslateErrors(self.stub.put_config(request), "putConfig")
  }
  
  func getConfigList(_ configKeyList: [String]) throws -> [String: String] {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetConfig_Request()
    request.configKeyList = configKeyList
    let response = try self.callAndTranslateErrors(self.stub.get_config(request), "getConfigList")

    assert(response.configList.count == configKeyList.count, "getConfigList(): response config count (\(response.configList.count)) "
            + "does not match request config count (\(configKeyList.count))")
    var configDict: [String: String] = [:]
    for config in response.configList {
      configDict[config.key] = config.val
    }
    return configDict
  }
  
  func putConfigList(_ configDict: [String: String]) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_PutConfig_Request()
    for (configKey, configVal) in configDict {
      var configEntry = Outlet_Backend_Agent_Grpc_Generated_ConfigEntry()
      configEntry.key = configKey
      configEntry.val = configVal
      request.configList.append(configEntry)
    }
    let _ = try self.callAndTranslateErrors(self.stub.put_config(request), "putConfigList")
  }

  func getIcon(_ iconID: IconID) throws -> NSImage? {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetIcon_Request()
    request.iconID = iconID.rawValue
    let response = try self.callAndTranslateErrors(self.stub.get_icon(request), "getIcon")

    if response.hasIcon {
      assert(iconID.rawValue == response.icon.iconID, "Response iconID (\(response.icon.iconID)) does not match request iconID (\(iconID))")
      NSLog("DEBUG Got image from server: \(iconID)")
      return NSImage(data: response.icon.content)
    } else {
      NSLog("DEBUG Server returned empty result for requested image: \(iconID)")
      return nil
    }
  }



  private func callAndTranslateErrors<Req, Res>(_ call: UnaryCall<Req, Res>, _ rpcName: String) throws -> Res {
    if !self.isConnected {
      throw OutletError.grpcConnectionDown("RPC '\(rpcName)' failed: client not connected!")
    } else {
      if SUPER_DEBUG_ENABLED {
        // We should avoid seeing the main queue show up here, as much as possible
        NSLog("DEBUG callAndTranslateErrors(): Current queue: '\(DispatchQueue.currentQueueLabel ?? "nil")'")
      }

      var exception: OutletError? = nil
      var response: Res? = nil
      // Run all calls inside a serial dispatch queue.
      self.dqGRPC.sync {
        do {
          NSLog("INFO  Calling gRPC: \(rpcName)")
          response = try call.response.wait()
        } catch is NIOConnectionError {
          self.app.grpcDidGoDown()
          exception = OutletError.grpcConnectionDown("RPC \"\(rpcName)\" failed: connection refused")
        } catch {
          // General failure. Maybe server internal error, or bad data, or something else
          exception = OutletError.grpcFailure("RPC \"\(rpcName)\" failed: \(error)")
        }
      }
      if let thrownException = exception {
        throw thrownException
      }
      return response!
    }
  }

  /** DO NOT call this method directly. Call self.app.grpcDidGoDown(), which will call this.
   */
  func grpcConnectionDown() {
    if self.isConnected {
      NSLog("INFO  gRPC connection is DOWN!")
      DispatchQueue.main.async {
        self.backendConnectionState.isConnected = false
      }
      self.closeChannel()  // If we got a watchdog timeout, we need to close the channel from our end, to un-hang the SignalReceiverThread
    }
  }

  private func grpcConnectionRestored() {
    if !self.isConnected {
      DispatchQueue.main.async {
        NSLog("INFO  gRPC connection is UP!")
        self.tryLocalHostFirst = false
        self.backendConnectionState.isConnected = true
        self.backendConnectionState.conecutiveStreamFailCount = 0  // reset failure count
        self.app.grpcDidGoUp()
      }
    }
  }

}
