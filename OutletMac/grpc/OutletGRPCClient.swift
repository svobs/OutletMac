//
//  OutletGRPCClient.swift
//  
//
//  Created by Matthew Svoboda on 2021-01-11.
//

import Foundation
import GRPC
import Logging
import NIO

/**
 CLASS OutletGRPCClient

 Thin gRPC client to the backend service
 */
class OutletGRPCClient: OutletBackend {
  let stub: Outlet_Backend_Agent_Grpc_Generated_OutletClient
  var signalReceiverThread: SignalReceiverThread?
  let dispatcher: SignalDispatcher
  let dispatchListener: DispatchListener
  var isConnected: Bool = true // set to true initially just for logging purposes: we care more to note if it's initially down than up
  lazy var grpcConverter = GRPCConverter(self)
  lazy var nodeIdentifierFactory = NodeIdentifierFactory(self)

  init(_ client: Outlet_Backend_Agent_Grpc_Generated_OutletClient, _ dispatcher: SignalDispatcher) {
    self.dispatcher = dispatcher
    self.stub = client
    self.dispatchListener = dispatcher.createListener(ID_BACKEND_CLIENT)
  }

  func start() throws {
    self.signalReceiverThread = SignalReceiverThread(self)
    self.signalReceiverThread!.start()

    // Forward the following Dispatcher signals across gRPC:
    try connectAndForwardSignal(.PAUSE_OP_EXECUTION)
    try connectAndForwardSignal(.RESUME_OP_EXECUTION)
    try connectAndForwardSignal(.COMPLETE_MERGE)
    try connectAndForwardSignal(.DOWNLOAD_ALL_GDRIVE_META)
    try connectAndForwardSignal(.DEREGISTER_DISPLAY_TREE)
  }
  
  func shutdown() throws {
    try self.stub.channel.close().wait()
    self.signalReceiverThread?.cancel()
  }

  private func connectAndForwardSignal(_ signal: Signal) throws {
    try self.dispatchListener.subscribe(signal: signal) { (senderID, propDict) in
      self.sendSignalToServer(signal, senderID)
    }
  }

  private func sendSignalToServer(_ signal: Signal, _ senderID: SenderID, _ propDict: PropDict? = nil) {
    var signalMsg = Outlet_Backend_Agent_Grpc_Generated_SignalMsg()
    signalMsg.sigInt = signal.rawValue
    signalMsg.sender = senderID
    _ = self.stub.send_signal(signalMsg)
  }

  private func relaySignalLocally(_ signalGRPC: Outlet_Backend_Agent_Grpc_Generated_SignalMsg) throws {
    let signal = Signal(rawValue: signalGRPC.sigInt)!
    NSLog("DEBUG GRPCClient: got signal from backend via gRPC: \(signal)")
    var argDict: [String: Any] = [:]

    switch signal {
      case .DISPLAY_TREE_CHANGED, .GENERATE_MERGE_TREE_DONE:
        let displayTreeUiState = try self.grpcConverter.displayTreeUiStateFromGRPC(signalGRPC.displayTreeUiState)
        let tree: DisplayTree = displayTreeUiState.toDisplayTree(backend: self)
        argDict["tree"] = tree
      case .OP_EXECUTION_PLAY_STATE_CHANGED:
        argDict["is_enabled"] = signalGRPC.playState.isEnabled
      case .TOGGLE_UI_ENABLEMENT:
        argDict["enable"] = signalGRPC.uiEnablement.enable
      case .ERROR_OCCURRED:
        argDict["msg"] = signalGRPC.errorOccurred.msg
        argDict["secondary_msg"] = signalGRPC.errorOccurred.secondaryMsg
      case .NODE_UPSERTED, .NODE_REMOVED:
        argDict["node"] = try self.grpcConverter.nodeFromGRPC(signalGRPC.node)
      case .NODE_MOVED:
        argDict["src_node"] = try self.grpcConverter.nodeFromGRPC(signalGRPC.srcDstNodeList.srcNode)
        argDict["dst_node"] = try self.grpcConverter.nodeFromGRPC(signalGRPC.srcDstNodeList.dstNode)
      case .SET_STATUS:
        argDict["status_msg"] = signalGRPC.statusMsg.msg
      case .DOWNLOAD_FROM_GDRIVE_DONE:
        argDict["filename"] = signalGRPC.downloadMsg.filename
      case .REFRESH_SUBTREE_STATS_DONE:
        argDict["status_msg"] = signalGRPC.statsUpdate.statusMsg
      default:
        break
    }
    argDict["signal"] = signal

    dispatcher.sendSignal(signal: signal, senderID: signalGRPC.sender, argDict)
  }
  
  func receiveServerSignals() throws {
    NSLog("DEBUG Subscribing to server signals...")
    let request = Outlet_Backend_Agent_Grpc_Generated_Subscribe_Request()
    let call = self.stub.subscribe_to_signals(request) { signalGRPC in
      NSLog("DEBUG Got new signal: \(signalGRPC.sigInt)")
      self.grpcConnectionRestored()
      do {
        try self.relaySignalLocally(signalGRPC)
      } catch {
        let signal = Signal(rawValue: signalGRPC.sigInt)!
        NSLog("ERROR While relaying received signal \(signal): \(error)")
      }
    }
    
    call.status.whenSuccess { status in
      if status.code == .ok {
        // this should never happen
        NSLog("INFO  Server closed signal subscription")
      } else if status.code == .unavailable {
        if SUPER_DEBUG {
          NSLog("ERROR ReceiveSignals(): Server unavailable: \(status)")
        }
        self.grpcConnectionDown()
      } else {
        NSLog("ERROR ReceiveSignals(): received error: \(status)")
      }
    }

    // Wait for the call to end.
    _ = try! call.status.wait()
    NSLog("DEBUG receiveServerSignals() returning")
  }

  /// Makes a `RouteGuide` client for a service hosted on "localhost" and listening on the given port.
  static func makeClient(host: String, port: Int, dispatcher: SignalDispatcher) -> OutletGRPCClient {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    let channel = ClientConnection.insecure(group: group)
      .withConnectionTimeout(minimum: TimeAmount.seconds(3))
      .withConnectionBackoff(retries: ConnectionBackoff.Retries.upTo(1))
      .connect(host: host, port: port)
    
    return OutletGRPCClient(Outlet_Backend_Agent_Grpc_Generated_OutletClient(channel: channel), dispatcher)
  }
  
  func requestDisplayTree(_ request: DisplayTreeRequest) throws -> DisplayTree? {
    NSLog("DEBUG Requesting DisplayTree for params: \(request)")
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
      NSLog("DEBUG Got state: \(state)")
      return state.toDisplayTree(backend: self)
    } else {
      return nil
    }
  }
  
  func getNodeForUID(uid: UID, deviceUID: UID?) throws -> Node? {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetNodeForUid_Request()
    request.uid = uid
    if let deviceUID = deviceUID {
      request.deviceUid = deviceUID
    }
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
    if uidSuggestion != nil {
      request.uidSuggestion = uidSuggestion!
    }
    let response = try self.callAndTranslateErrors(self.stub.get_uid_for_local_path(request), "getUIDForLocalPath")

    return response.uid
  }
  
  func startSubtreeLoad(treeID: String) throws {
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
      let treeType: TreeType = TreeType(rawValue: deviceGRPC.treeType)!
      deviceList.append(Device(device_uid: deviceGRPC.deviceUid, long_device_id: deviceGRPC.longDeviceID, treeType: treeType, friendlyName: deviceGRPC.friendlyName))
    }
    return deviceList
  }
  
  func getChildList(parentUID: UID, treeID: String?, maxResults: UInt32?) throws -> [Node] {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetChildList_Request()
    if treeID != nil {
      request.treeID = treeID!
    }
    request.parentUid = parentUID
    request.maxResults = maxResults ?? 0

    let response = try self.callAndTranslateErrors(self.stub.get_child_list_for_node(request), "getChildList")

    if response.resultExceededCount > 0 {
      assert (maxResults != nil && maxResults! > 0)
      throw OutletError.maxResultsExceeded(actualCount: response.resultExceededCount)
    }

    return try self.grpcConverter.nodeListFromGRPC(response.nodeList)
  }
  
  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [Node] {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetAncestorList_Request()
    request.stopAtPath = stopAtPath ?? ""
    request.spid = try self.grpcConverter.nodeIdentifierToGRPC(spid)

    let response = try self.callAndTranslateErrors(self.stub.get_ancestor_list_for_spid(request), "getAncestorList")
    return try self.grpcConverter.nodeListFromGRPC(response.nodeList)
  }

  func getRowsOfInterest(treeID: String) throws -> RowsOfInterest {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetRowsOfInterest_Request()
    request.treeID = treeID

    let response = try self.callAndTranslateErrors(self.stub.get_rows_of_interest(request), "getRowsOfInterest")

    let rows = RowsOfInterest()
    for uid in response.expandedRowUidSet {
      rows.expanded.insert(uid)
    }
    for uid in response.selectedRowUidSet {
      rows.selected.insert(uid)
    }
    return rows
  }

  func setSelectedRowSet(_ selected: Set<UID>, _ treeID: String) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_SetSelectedRowSet_Request()
    for uid in selected {
      request.selectedRowUidSet.append(uid)
    }
    request.treeID = treeID

    let _ = try self.callAndTranslateErrors(self.stub.set_selected_row_set(request), "setSelectedRowSet")
  }

  func removeExpandedRow(_ rowUID: UID, _ treeID: String) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_RemoveExpandedRow_Request()
    request.nodeUid = rowUID
    request.treeID = treeID

    let _ = try self.callAndTranslateErrors(self.stub.remove_expanded_row(request), "removeExpandedRow")
  }

  func createDisplayTreeForGDriveSelect(deviceUID: UID) throws -> DisplayTree? {
    let spid = self.nodeIdentifierFactory.getRootConstantGDriveSPID(deviceUID)
    let request = DisplayTreeRequest(treeID: ID_GDRIVE_DIR_SELECT, returnAsync: false, spid: spid, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }
  
  func createDisplayTreeFromConfig(treeID: String, isStartup: Bool = false) throws -> DisplayTree? {
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: false, isStartup: isStartup, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }
  
  func createDisplayTreeFromSPID(treeID: String, spid: SinglePathNodeIdentifier) throws -> DisplayTree? {
    // Note: this shouldn't actually return anything, as returnAsync==true
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: true, spid: spid, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }
  
  func createDisplayTreeFromUserPath(treeID: String, userPath: String, deviceUID: UID) throws -> DisplayTree? {
    // Note: this shouldn't actually return anything, as returnAsync==true
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: true, userPath: userPath, deviceUID: deviceUID, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
    return try self.requestDisplayTree(request)
  }

  func createExistingDisplayTree(treeID: String, treeDisplayMode: TreeDisplayMode) throws -> DisplayTree? {
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
    if request.spid != nil {
      requestGRPC.spid = try self.grpcConverter.nodeIdentifierToGRPC(request.spid!)
    }
    requestGRPC.treeDisplayMode = request.treeDisplayMode.rawValue

    let response = try self.callAndTranslateErrors(self.stub.request_display_tree(requestGRPC), "requestDisplayTree")

    let tree: DisplayTree?
    if response.hasDisplayTreeUiState {
      let state = try self.grpcConverter.displayTreeUiStateFromGRPC(response.displayTreeUiState)
      tree = state.toDisplayTree(backend: self)
      NSLog("Returning DisplayTree: \(tree!)")
    } else {
      tree = nil
      NSLog("Returning DisplayTree==null")
    }

    return tree
  }
  
  func dropDraggedNodes(srcTreeID: String, srcSNList: [SPIDNodePair], isInto: Bool, dstTreeID: String, dstSN: SPIDNodePair) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_DragDrop_Request()
    request.srcTreeID = srcTreeID
    request.dstTreeID = dstTreeID
    for srcSN in srcSNList {
      request.srcSnList.append(try self.grpcConverter.snToGRPC(srcSN))
    }
    request.isInto = isInto
    request.dstSn = try self.grpcConverter.snToGRPC(dstSN)

    let _ = try self.callAndTranslateErrors(self.stub.drop_dragged_nodes(request), "dropDraggedNodes")
  }
  
  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs {
    var request = Outlet_Backend_Agent_Grpc_Generated_StartDiffTrees_Request()
    request.treeIDLeft = treeIDLeft
    request.treeIDRight = treeIDRight

    let response = try self.callAndTranslateErrors(self.stub.start_diff_trees(request), "startDiffTrees")
    let treeIDs = DiffResultTreeIDs(left: response.treeIDLeft, right: response.treeIDRight)
    return treeIDs
  }
  
  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [SPIDNodePair], selectedChangeListRight: [SPIDNodePair]) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_GenerateMergeTree_Request()
    request.treeIDLeft = treeIDLeft
    request.treeIDRight = treeIDRight
    for sn in selectedChangeListLeft {
      request.changeListLeft.append(try self.grpcConverter.snToGRPC(sn))
    }
    for sn in selectedChangeListRight {
      request.changeListRight.append(try self.grpcConverter.snToGRPC(sn))
    }

    let _ = try self.callAndTranslateErrors(self.stub.generate_merge_tree(request), "generateMergeTree")
  }
  
  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: String) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_RefreshSubtree_Request()
    request.nodeIdentifier = try self.grpcConverter.nodeIdentifierToGRPC(nodeIdentifier)
    request.treeID = treeID
    let _ = try self.callAndTranslateErrors(self.stub.refresh_subtree(request), "enqueueRefreshSubtreeTask")
  }
  
  func enqueueRefreshSubtreeStatsTask(rootUID: UID, treeID: String) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_RefreshSubtreeStats_Request()
    request.rootUid = rootUID
    request.treeID = treeID
    let _ = try self.callAndTranslateErrors(self.stub.refresh_subtree_stats(request), "enqueueRefreshSubtreeStatsTask")
  }
  
  func getLastPendingOp(nodeUID: UID) throws -> UserOp? {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetLastPendingOp_Request()
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
    let opType = UserOpType(rawValue: response.userOp.opType)!

    return UserOp(opUID: response.userOp.opUid, batchUID: response.userOp.batchUid, opType: opType, srcNode: srcNode, dstNode: dstNode)
  }
  
  func downloadFileFromGDrive(nodeUID: UID, requestorID: String) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_DownloadFromGDrive_Request()
    request.nodeUid = nodeUID
    request.requestorID = requestorID
    let _ = try self.callAndTranslateErrors(self.stub.download_file_from_gdrive(request), "downloadFileFromGDrive")
  }
  
  func deleteSubtree(nodeUIDList: [UID]) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_DeleteSubtree_Request()
    request.nodeUidList = nodeUIDList
    let _ = try self.callAndTranslateErrors(self.stub.delete_subtree(request), "deleteSubtree")
  }
  
  func getFilterCriteria(treeID: String) throws -> FilterCriteria {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetFilter_Request()
    request.treeID = treeID
    let response = try self.callAndTranslateErrors(self.stub.get_filter(request), "getFilterCriteria")
    if response.hasFilterCriteria {
      let filterCriteria = try self.grpcConverter.filterCriteriaFromGRPC(response.filterCriteria)
      NSLog("[\(treeID)] Got: \(filterCriteria)")
      return filterCriteria
    } else {
      throw OutletError.invalidState("No FilterCriteria (probably unknown tree) for tree: \(treeID)")
    }
  }
  
  func updateFilterCriteria(treeID: String, filterCriteria: FilterCriteria) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_UpdateFilter_Request()
    request.treeID = treeID
    request.filterCriteria = try self.grpcConverter.filterCriteriaToGRPC(filterCriteria)
    let _ = try self.callAndTranslateErrors(self.stub.update_filter(request), "updateFilterCriteria")
  }

  func getConfig(_ configKey: String, defaultVal: String? = nil) throws -> String {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetConfig_Request()
    request.configKeyList.append(configKey)
    let call = self.stub.get_config(request)
    do {
      let response = try call.response.wait()
      if response.configList.count != 1 {
        throw OutletError.invalidState("RPC 'getFilterCriteria' failed: got more than one value for config list")
      } else {
        assert(response.configList[0].key == configKey, "getConfig(): response key (\(response.configList[0].key)) != expected (\(configKey))")
        return response.configList[0].val
      }
    } catch {
      throw OutletError.grpcFailure("RPC 'getConfig' failed: \(error)")
    }
  }
  
  func getIntConfig(_ configKey: String, defaultVal: Int? = nil) throws -> Int {
    if SUPER_DEBUG {
      NSLog("DEBUG getIntConfig entered")
    }
    let defaultValStr: String?
    if defaultVal == nil {
      defaultValStr = nil
    } else {
      defaultValStr = String(defaultVal!)
    }
    let configVal: String = try self.getConfig(configKey, defaultVal: defaultValStr)
    let configValInt = Int(configVal)
    if configValInt == nil {
      throw OutletError.invalidState("Failed to parse value '\(configVal)' as int for key '\(configKey)'")
    } else {
      NSLog("DEBUG getIntConfig returning: \(configValInt!)")
      return configValInt!
    }
  }

  func getBoolConfig(_ configKey: String, defaultVal: Bool? = nil) throws -> Bool {
    if SUPER_DEBUG {
      NSLog("DEBUG getBoolConfig entered")
    }
    let defaultValStr: String? = (defaultVal == nil) ? nil : String(defaultVal!)
    let configVal: String = try self.getConfig(configKey, defaultVal: defaultValStr)
    let configValBool = Bool(configVal.lowercased())
    if configValBool == nil {
      throw OutletError.invalidState("Failed to parse value '\(configVal)' as bool for key '\(configKey)'")
    } else {
      NSLog("DEBUG getBoolConfig returning: \(configValBool!)")
      return configValBool!
    }
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

  func callAndTranslateErrors<Req, Res>(_ call: UnaryCall<Req, Res>, _ rpcName: String) throws -> Res {
    do {
      return try call.response.wait()
    } catch is NIOConnectionError {
      self.grpcConnectionDown()
      throw OutletError.grpcConnectionDown("RPC '\(rpcName)' failed: connection refused")
    } catch {
      // General failure. Maybe server internal error, or bad data, or something else
      throw OutletError.grpcFailure("RPC '\(rpcName)' failed: \(error)")
    }
  }

  func grpcConnectionDown() {
    if self.isConnected {
      self.isConnected = false
      NSLog("INFO  gRPC connection is DOWN!")
    }
  }

  func grpcConnectionRestored() {
    if !self.isConnected {
      self.isConnected = true
      NSLog("INFO  gRPC connection is UP!")
    }
    self.signalReceiverThread?.loopCount = 0
  }

}
