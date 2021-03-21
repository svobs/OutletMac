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
  let stub: Outlet_Backend_Daemon_Grpc_Generated_OutletClient
  var signalReceiverThread: SignalReceiverThread?
  let dispatcher: SignalDispatcher
  let dispatchListener: DispatchListener

  init(_ client: Outlet_Backend_Daemon_Grpc_Generated_OutletClient, _ dispatcher: SignalDispatcher) {
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
    var signalMsg = Outlet_Backend_Daemon_Grpc_Generated_SignalMsg()
    signalMsg.sigInt = signal.rawValue
    signalMsg.sender = senderID
    _ = self.stub.send_signal(signalMsg)
  }

  private func relaySignalLocally(_ signalGRPC: Outlet_Backend_Daemon_Grpc_Generated_SignalMsg) throws {
    let signal = Signal(rawValue: signalGRPC.sigInt)!
    NSLog("DEBUG GRPCClient: got signal from backend via gRPC: \(signal)")
    var argDict: [String: Any] = [:]

    switch signal {
      case .DISPLAY_TREE_CHANGED, .GENERATE_MERGE_TREE_DONE:
        let displayTreeUiState = try GRPCConverter.displayTreeUiStateFromGRPC(signalGRPC.displayTreeUiState)
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
        argDict["node"] = try GRPCConverter.nodeFromGRPC(signalGRPC.node)
      case .NODE_MOVED:
        argDict["src_node"] = try GRPCConverter.nodeFromGRPC(signalGRPC.srcDstNodeList.srcNode)
        argDict["dst_node"] = try GRPCConverter.nodeFromGRPC(signalGRPC.srcDstNodeList.dstNode)
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
    let request = Outlet_Backend_Daemon_Grpc_Generated_Subscribe_Request()
    let call = self.stub.subscribe_to_signals(request) { signalGRPC in
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
    
    return OutletGRPCClient(Outlet_Backend_Daemon_Grpc_Generated_OutletClient(channel: channel), dispatcher)
  }
  
  func requestDisplayTree(_ request: DisplayTreeRequest) throws -> DisplayTree? {
    NSLog("DEBUG Requesting DisplayTree for params: \(request)")
    var grpcRequest = Outlet_Backend_Daemon_Grpc_Generated_RequestDisplayTree_Request()
    grpcRequest.isStartup = request.isStartup
    grpcRequest.treeID = request.treeID
    grpcRequest.userPath = request.userPath ?? ""
    grpcRequest.returnAsync = request.returnAsync
    grpcRequest.treeDisplayMode = request.treeDisplayMode.rawValue
    
    if let spid = request.spid {
      grpcRequest.spid = try GRPCConverter.nodeIdentifierToGRPC(spid)
    }
    
    let call = self.stub.request_display_tree_ui_state(grpcRequest)
    
    do {
      let response = try call.response.wait()
      if (response.hasDisplayTreeUiState) {
        let state: DisplayTreeUiState = try GRPCConverter.displayTreeUiStateFromGRPC(response.displayTreeUiState)
        NSLog("DEBUG Got state: \(state)")
        return state.toDisplayTree(backend: self)
      } else {
        return nil
      }
    } catch {
      throw OutletError.grpcFailure("RPC 'requestDisplayTree' failed: \(error)")
    }
  }
  
  func getNodeForUID(uid: UID, treeType: TreeType?) throws -> Node? {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetNodeForUid_Request()
    request.uid = uid
    if let tt = treeType?.rawValue {
      request.treeType = tt
    }
    let call = self.stub.get_node_for_uid(request)
    do {
      let response = try call.response.wait()
      if (response.hasNode) {
        return try GRPCConverter.nodeFromGRPC(response.node)
      } else {
        return nil
      }
    } catch {
      throw OutletError.grpcFailure("RPC 'getNodeForUID' failed: \(error)")
    }
  }
  
  func getNodeForLocalPath(fullPath: String) throws -> Node? {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetNodeForLocalPath_Request()
    request.fullPath = fullPath
    let call = self.stub.get_node_for_local_path(request)
    do {
      let response = try call.response.wait()
      if (response.hasNode) {
        return try GRPCConverter.nodeFromGRPC(response.node)
      } else {
        return nil
      }
    } catch {
      throw OutletError.grpcFailure("RPC 'getNodeForLocalPath' failed: \(error)")
    }
  }
  
  func nextUID() throws -> UID {
    let call = self.stub.get_next_uid(Outlet_Backend_Daemon_Grpc_Generated_GetNextUid_Request())
    do {
      let response = try call.response.wait()
      return response.uid
    } catch {
      throw OutletError.grpcFailure("RPC 'nextUID' failed: \(error)")
    }
  }
  
  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID? {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetUidForLocalPath_Request()
    request.fullPath = fullPath
    if uidSuggestion != nil {
      request.uidSuggestion = uidSuggestion!
    }
    let call = self.stub.get_uid_for_local_path(request)
    do {
      let response = try call.response.wait()
      return response.uid
    } catch {
      throw OutletError.grpcFailure("RPC 'getUIDForLocalPath' failed: \(error)")
    }
  }
  
  func startSubtreeLoad(treeID: String) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_StartSubtreeLoad_Request()
    request.treeID = treeID
    let call = self.stub.start_subtree_load(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'startSubtreeLoad' failed: \(error)")
    }
  }
  
  func getOpExecutionPlayState() throws -> Bool {
    let call = self.stub.get_op_exec_play_state(Outlet_Backend_Daemon_Grpc_Generated_GetOpExecPlayState_Request())
    do {
      let response = try call.response.wait()
      
      return response.isEnabled
    } catch {
      throw OutletError.grpcFailure("RPC 'getOpExecutionPlayState' failed: \(error)")
    }
  }
  
  func getChildList(parentUID: UID, treeID: String?, maxResults: UInt32?) throws -> [Node] {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetChildList_Request()
    if treeID != nil {
      request.treeID = treeID!
    }
    request.parentUid = parentUID
    request.maxResults = maxResults ?? 0
    
    let call = self.stub.get_child_list_for_node(request)
    let response: Outlet_Backend_Daemon_Grpc_Generated_GetChildList_Response
    do {
      response = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'getChildList' failed: \(error)")
    }

    if response.resultExceededCount > 0 {
      assert (maxResults != nil && maxResults! > 0)
      throw OutletError.maxResultsExceeded(actualCount: response.resultExceededCount)
    }

    return try GRPCConverter.nodeListFromGRPC(response.nodeList)
  }
  
  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [Node] {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetAncestorList_Request()
    request.stopAtPath = stopAtPath ?? ""
    request.spid = try GRPCConverter.nodeIdentifierToGRPC(spid)
    
    let call = self.stub.get_ancestor_list_for_spid(request)
    do {
      let response = try call.response.wait()
      return try GRPCConverter.nodeListFromGRPC(response.nodeList)
    } catch {
      throw OutletError.grpcFailure("RPC 'getAncestorList' failed: \(error)")
    }
  }

  func getRowsOfInterest(treeID: String) throws -> RowsOfInterest {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetRowsOfInterest_Request()
    request.treeID = treeID

    let call = self.stub.get_rows_of_interest(request)
    do {
      let response = try call.response.wait()
      let rows = RowsOfInterest()
      for uid in response.expandedRowUidSet {
        rows.expanded.insert(uid)
      }
      for uid in response.selectedRowUidSet {
        rows.selected.insert(uid)
      }
      return rows
    } catch {
      throw OutletError.grpcFailure("RPC 'getRowsOfInterest' failed: \(error)")
    }
  }

  func setSelectedRowSet(_ selected: Set<UID>, _ treeID: String) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_SetSelectedRowSet_Request()
    for uid in selected {
      request.selectedRowUidSet.append(uid)
    }
    request.treeID = treeID

    let call = self.stub.set_selected_row_set(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'setSelectedRowSet' failed: \(error)")
    }
  }

  func removeExpandedRow(_ rowUID: UID, _ treeID: String) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_RemoveExpandedRow_Request()
    request.nodeUid = rowUID
    request.treeID = treeID

    let call = self.stub.remove_expanded_row(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'removeExpandedRow' failed: \(error)")
    }
  }

  func createDisplayTreeForGDriveSelect() throws -> DisplayTree? {
    let spid = NodeIdentifierFactory.getRootConstantGDriveSPID()
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
  
  func createDisplayTreeFromUserPath(treeID: String, userPath: String) throws -> DisplayTree? {
    // Note: this shouldn't actually return anything, as returnAsync==true
    let request = DisplayTreeRequest(treeID: treeID, returnAsync: true, userPath: userPath, treeDisplayMode: .ONE_TREE_ALL_ITEMS)
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
    var requestGRPC = Outlet_Backend_Daemon_Grpc_Generated_RequestDisplayTree_Request()
    requestGRPC.isStartup = request.isStartup
    requestGRPC.treeID = request.treeID
    requestGRPC.returnAsync = request.returnAsync
    requestGRPC.userPath = request.userPath ?? ""
    if request.spid != nil {
      requestGRPC.spid = try GRPCConverter.nodeIdentifierToGRPC(request.spid!)
    }
    requestGRPC.treeDisplayMode = request.treeDisplayMode.rawValue
    
    let call = self.stub.request_display_tree_ui_state(requestGRPC)
    do {
      let response = try call.response.wait()
      
      let tree: DisplayTree?
      if response.hasDisplayTreeUiState {
        let state = try GRPCConverter.displayTreeUiStateFromGRPC(response.displayTreeUiState)
        tree = state.toDisplayTree(backend: self)
        NSLog("Returning DisplayTree: \(tree!)")
      } else {
        tree = nil
        NSLog("Returning DisplayTree==null")
      }
      
      return tree
    } catch {
      throw OutletError.grpcFailure("RPC 'requestDisplayTree' failed: \(error)")
    }
  }
  
  func dropDraggedNodes(srcTreeID: String, srcSNList: [SPIDNodePair], isInto: Bool, dstTreeID: String, dstSN: SPIDNodePair) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_DragDrop_Request()
    request.srcTreeID = srcTreeID
    request.dstTreeID = dstTreeID
    for srcSN in srcSNList {
      request.srcSnList.append(try GRPCConverter.snToGRPC(srcSN))
    }
    request.isInto = isInto
    request.dstSn = try GRPCConverter.snToGRPC(dstSN)
    
    let call = self.stub.drop_dragged_nodes(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'dropDraggedNodes' failed: \(error)")
    }
  }
  
  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs {
    var request = Outlet_Backend_Daemon_Grpc_Generated_StartDiffTrees_Request()
    request.treeIDLeft = treeIDLeft
    request.treeIDRight = treeIDRight
    
    let call = self.stub.start_diff_trees(request)
    do {
      let response = try call.response.wait()
      
      let treeIDs = DiffResultTreeIDs(left: response.treeIDLeft, right: response.treeIDRight)
      return treeIDs
    } catch {
      throw OutletError.grpcFailure("RPC 'startDiffTrees' failed: \(error)")
    }
  }
  
  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [SPIDNodePair], selectedChangeListRight: [SPIDNodePair]) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GenerateMergeTree_Request()
    request.treeIDLeft = treeIDLeft
    request.treeIDRight = treeIDRight
    for sn in selectedChangeListLeft {
      request.changeListLeft.append(try GRPCConverter.snToGRPC(sn))
    }
    for sn in selectedChangeListRight {
      request.changeListRight.append(try GRPCConverter.snToGRPC(sn))
    }
    
    let call = self.stub.generate_merge_tree(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'generateMergeTree' failed: \(error)")
    }
  }
  
  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: String) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_RefreshSubtree_Request()
    request.nodeIdentifier = try GRPCConverter.nodeIdentifierToGRPC(nodeIdentifier)
    request.treeID = treeID
    let call = self.stub.refresh_subtree(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'enqueueRefreshSubtreeTask' failed: \(error)")
    }
  }
  
  func enqueueRefreshSubtreeStatsTask(rootUID: UID, treeID: String) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_RefreshSubtreeStats_Request()
    request.rootUid = rootUID
    request.treeID = treeID
    let call = self.stub.refresh_subtree_stats(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'enqueueRefreshSubtreeStatsTask' failed: \(error)")
    }
  }
  
  func getLastPendingOp(nodeUID: UID) throws -> UserOp? {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetLastPendingOp_Request()
    request.nodeUid = nodeUID
    
    let call = self.stub.get_last_pending_op_for_node(request)
    do {
      let response = try call.response.wait()
      
      if !response.hasUserOp {
        return nil
      }
      let srcNode = try GRPCConverter.nodeFromGRPC(response.userOp.srcNode)
      let dstNode: Node?
      if response.userOp.hasDstNode {
        dstNode = try GRPCConverter.nodeFromGRPC(response.userOp.dstNode)
      } else {
        dstNode = nil
      }
      let opType = UserOpType(rawValue: response.userOp.opType)!
      
      return UserOp(opUID: response.userOp.opUid, batchUID: response.userOp.batchUid, opType: opType, srcNode: srcNode, dstNode: dstNode)
    } catch {
      throw OutletError.grpcFailure("RPC 'getLastPendingOp' failed: \(error)")
    }
  }
  
  func downloadFileFromGDrive(nodeUID: UID, requestorID: String) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_DownloadFromGDrive_Request()
    request.nodeUid = nodeUID
    request.requestorID = requestorID
    let call = self.stub.download_file_from_gdrive(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'downloadFileFromGDrive' failed: \(error)")
    }
  }
  
  func deleteSubtree(nodeUIDList: [UID]) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_DeleteSubtree_Request()
    request.nodeUidList = nodeUIDList
    let call = self.stub.delete_subtree(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'deleteSubtree' failed: \(error)")
    }
  }
  
  func getFilterCriteria(treeID: String) throws -> FilterCriteria {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetFilter_Request()
    request.treeID = treeID
    let call = self.stub.get_filter(request)
    do {
      let response = try call.response.wait()
      if response.hasFilterCriteria {
        let filterCriteria = try GRPCConverter.filterCriteriaFromGRPC(response.filterCriteria)
        NSLog("[\(treeID)] Got: \(filterCriteria)")
        return filterCriteria
      } else {
        throw OutletError.invalidState("No FilterCriteria (probably unknown tree) for tree: \(treeID)")
      }
    } catch {
      throw OutletError.grpcFailure("RPC 'getFilterCriteria' failed: \(error)")
    }
  }
  
  func updateFilterCriteria(treeID: String, filterCriteria: FilterCriteria) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_UpdateFilter_Request()
    request.treeID = treeID
    request.filterCriteria = try GRPCConverter.filterCriteriaToGRPC(filterCriteria)
    let call = self.stub.update_filter(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'updateFilterCriteria' failed: \(error)")
    }
  }

  func getConfig(_ configKey: String, defaultVal: String? = nil) throws -> String {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetConfig_Request()
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
    var request = Outlet_Backend_Daemon_Grpc_Generated_PutConfig_Request()
    var configEntry = Outlet_Backend_Daemon_Grpc_Generated_ConfigEntry()
    configEntry.key = configKey
    configEntry.val = configVal
    request.configList.append(configEntry)
    let call = self.stub.put_config(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'putConfig' failed: \(error)")
    }
  }
  
  func getConfigList(_ configKeyList: [String]) throws -> [String: String] {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetConfig_Request()
    request.configKeyList = configKeyList
    let call = self.stub.get_config(request)
    do {
      let response = try call.response.wait()
      assert(response.configList.count == configKeyList.count, "getConfigList(): response config count (\(response.configList.count)) "
              + "does not match request config count (\(configKeyList.count))")
      var configDict: [String: String] = [:]
      for config in response.configList {
        configDict[config.key] = config.val
      }
      return configDict
    } catch {
      throw OutletError.grpcFailure("RPC 'getConfigList' failed: \(error)")
    }
  }
  
  func putConfigList(_ configDict: [String: String]) throws {
    var request = Outlet_Backend_Daemon_Grpc_Generated_PutConfig_Request()
    for (configKey, configVal) in configDict {
      var configEntry = Outlet_Backend_Daemon_Grpc_Generated_ConfigEntry()
      configEntry.key = configKey
      configEntry.val = configVal
      request.configList.append(configEntry)
    }
    let call = self.stub.put_config(request)
    do {
      let _ = try call.response.wait()
    } catch {
      throw OutletError.grpcFailure("RPC 'putConfig' failed: \(error)")
    }
  }

  func getIcon(_ iconID: IconID) throws -> NSImage? {
    var request = Outlet_Backend_Daemon_Grpc_Generated_GetIcon_Request()
    request.iconID = iconID.rawValue
    let call = self.stub.get_icon(request)
    do {
      let response = try call.response.wait()
      if response.hasIcon {
        assert(iconID.rawValue == response.icon.iconID, "Response iconID (\(response.icon.iconID)) does not match request iconID (\(iconID))")
        NSLog("DEBUG Got image from server: \(iconID)")
        return NSImage(data: response.icon.content)
      } else {
        NSLog("DEBUG Server returned empty result for requested image: \(iconID)")
        return nil
      }
    } catch {
      throw OutletError.grpcFailure("RPC 'getIcon' failed: \(error)")
    }
  }
}
