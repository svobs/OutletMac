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
 */
class BackendConnectionState: ObservableObject {
  @Published var host: String
  @Published var port: Int

  @Published var conecutiveStreamFailCount: Int = 0
  // set to true initially just for logging purposes: we care more to note if it's initially down than up:
  @Published var isConnected: Bool = true
  @Published var isRelaunching: Bool = false

  init(host: String, port: Int) {
    self.host = host
    self.port = port
  }
}

/**
 CLASS OutletGRPCClient

 Thin gRPC client to the backend service
 */
class OutletGRPCClient: OutletBackend {
  var stub: Outlet_Backend_Agent_Grpc_Generated_OutletClient
  let app: OutletApp
  let backendConnectionState: BackendConnectionState
  let dispatchListener: DispatchListener
  lazy var grpcConverter = GRPCConverter(self)
  lazy var nodeIdentifierFactory = NodeIdentifierFactory(self)

  var isConnected: Bool {
    get {
      return self.backendConnectionState.isConnected
    }
  }

  init(_ client: Outlet_Backend_Agent_Grpc_Generated_OutletClient, _ app: OutletApp, _ backendConnectionState: BackendConnectionState) {
    self.app = app
    self.stub = client
    self.dispatchListener = app.dispatcher.createListener(ID_BACKEND_CLIENT)
    self.backendConnectionState = backendConnectionState
  }

  func replaceStub() {
    do {
      try self.stub.channel.close().wait()
    } catch {
      NSLog("ERROR While closing client stub: \(error)")
    }

    self.stub = OutletGRPCClient.makeClientStub(self.backendConnectionState.host, self.backendConnectionState.port)
  }

  /**
   Factory method: makes a `Outlet_Backend_Agent_Grpc_Generated_OutletClient` client for a service hosted on {host} and listening on {port}.
   */
  static func makeClient(app: OutletApp, _ conn: BackendConnectionState) ->
          OutletGRPCClient {
    return OutletGRPCClient(OutletGRPCClient.makeClientStub(conn.host, conn.port), app, conn)
  }

  private static func makeClientStub(_ host: String, _ port: Int) -> Outlet_Backend_Agent_Grpc_Generated_OutletClient {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let channel = ClientConnection.insecure(group: group)
            .withConnectionTimeout(minimum: TimeAmount.seconds(3))
            .withConnectionBackoff(retries: ConnectionBackoff.Retries.upTo(1))
            .connect(host: host, port: port)

    return Outlet_Backend_Agent_Grpc_Generated_OutletClient(channel: channel)
  }

  func start() throws {
    NSLog("DEBUG Starting OutletGRPCClient...")

    // Forward the following Dispatcher signals across gRPC:
    connectAndForwardSignal(.PAUSE_OP_EXECUTION)
    connectAndForwardSignal(.RESUME_OP_EXECUTION)
    connectAndForwardSignal(.COMPLETE_MERGE)
    connectAndForwardSignal(.DEREGISTER_DISPLAY_TREE)
    connectAndForwardSignal(.EXIT_DIFF_MODE)
  }
  
  func shutdown() throws {
    try self.stub.channel.close().wait()
  }

  // Signals
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func connectAndForwardSignal(_ signal: Signal) {
    self.dispatchListener.subscribe(signal: signal) { (senderID, propDict) in
      self.sendSignalToServer(signal, senderID)
    }
  }

  private func sendSignalToServer(_ signal: Signal, _ senderID: SenderID, _ propDict: PropDict? = nil) {
    var signalMsg = Outlet_Backend_Agent_Grpc_Generated_SignalMsg()
    signalMsg.sigInt = signal.rawValue
    signalMsg.sender = senderID
    _ = self.stub.send_signal(signalMsg)
  }

  /**
   Receives signals from the gRPC server and forwards them throughout the app via the app's Dispatcher.
   */
  func receiveServerSignals() {
    NSLog("DEBUG Subscribing to server signals...")
    let request = Outlet_Backend_Agent_Grpc_Generated_Subscribe_Request()
    let call = self.stub.subscribe_to_signals(request) { signalGRPC in
      // Got new signal (implicitly this means the connection is back up)

      if TRACE_ENABLED {
        NSLog("DEBUG Got new signal: \(signalGRPC.sigInt)")
      }
      self.grpcConnectionRestored()
      do {
        try self.relaySignalLocally(signalGRPC)
      } catch {
        let signal = Signal(rawValue: signalGRPC.sigInt)!
        NSLog("ERROR While relaying received signal \(signal): \(error)")
        self.reportError("While relaying received signal \(signal)", "\(error)")
      }
    }

    call.status.whenSuccess { status in
      // Yes, it says "whenSuccess" above, but this is actually always a failure of some kind.
      self.backendConnectionState.conecutiveStreamFailCount += 1

      if status.code == .ok {
        // this should never happen if the server was properly written
        NSLog("INFO  Server closed signal subscription")
      } else if status.code == .unavailable {
        if SUPER_DEBUG_ENABLED {
          NSLog("ERROR ReceiveSignals(): Server unavailable: \(status)")
        }
      } else {
        NSLog("ERROR ReceiveSignals(): received error: \(status)")
      }
      self.grpcConnectionDown()
    }

    // Wait for the call to end. It will only end if an error occurred (see call.status.whenSuccess above)
    _ = try! call.status.wait()
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG receiveServerSignals() returning")
    }
  }

  private func relaySignalLocally(_ signalGRPC: Outlet_Backend_Agent_Grpc_Generated_SignalMsg) throws {
    let signal = Signal(rawValue: signalGRPC.sigInt)!
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
      case .ERROR_OCCURRED:
        argDict["msg"] = signalGRPC.errorOccurred.msg
        argDict["secondary_msg"] = signalGRPC.errorOccurred.secondaryMsg
      case .NODE_UPSERTED, .NODE_REMOVED:
        argDict["sn"] = try self.grpcConverter.snFromGRPC(signalGRPC.sn)
        argDict["parent_guid"] = signalGRPC.parentGuid
      case .SET_STATUS:
        argDict["status_msg"] = signalGRPC.statusMsg.msg
      case .DOWNLOAD_FROM_GDRIVE_DONE:
        argDict["filename"] = signalGRPC.downloadMsg.filename
      case .REFRESH_SUBTREE_STATS_DONE:
        argDict["status_msg"] = signalGRPC.statsUpdate.statusMsg

        if signalGRPC.statsUpdate.dirMetaList.count > 0 {
          // TODO: this API could be improved by adding separate fields for UID-based vs GUID-based entries
          if signalGRPC.statsUpdate.dirMetaList[0].uid > 0 {
            var dirStatsDict: [UID:DirectoryStats] = [:]
            for dirMetaUpdate in signalGRPC.statsUpdate.dirMetaList {
              dirStatsDict[dirMetaUpdate.uid] = try self.grpcConverter.dirMetaFromGRPC(dirMetaUpdate.dirMeta)
            }
            argDict["dir_stats_dict_uid"] = dirStatsDict
          } else {
            var dirStatsDict: [GUID:DirectoryStats] = [:]
            for dirMetaUpdate in signalGRPC.statsUpdate.dirMetaList {
              dirStatsDict[dirMetaUpdate.guid] = try self.grpcConverter.dirMetaFromGRPC(dirMetaUpdate.dirMeta)
            }
            argDict["dir_stats_dict_guid"] = dirStatsDict
          }
        }
      default:
        break
    }
    argDict["signal"] = signal

    app.dispatcher.sendSignal(signal: signal, senderID: signalGRPC.sender, argDict)
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
      let treeType: TreeType = TreeType(rawValue: deviceGRPC.treeType)!
      deviceList.append(Device(device_uid: deviceGRPC.deviceUid, long_device_id: deviceGRPC.longDeviceID, treeType: treeType, friendlyName: deviceGRPC.friendlyName))
    }
    return deviceList
  }
  
  func getChildList(parentSPID: SPID, treeID: TreeID?, isExpandingParent: Bool = false, maxResults: UInt32?) throws -> [SPIDNodePair] {
    var request = Outlet_Backend_Agent_Grpc_Generated_GetChildList_Request()
    if treeID != nil {
      request.treeID = treeID!
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

  func dropDraggedNodes(srcTreeID: TreeID, srcGUIDList: [GUID], isInto: Bool, dstTreeID: TreeID, dstGUID: GUID) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_DragDrop_Request()
    request.srcTreeID = srcTreeID
    request.dstTreeID = dstTreeID
    request.dstGuid = dstGUID
    for srcGUID in srcGUIDList {
      request.srcGuidList.append(srcGUID)
    }
    request.isInto = isInto

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
  
  func enqueueRefreshSubtreeStatsTask(rootUID: UID, treeID: TreeID) throws {
    var request = Outlet_Backend_Agent_Grpc_Generated_RefreshSubtreeStats_Request()
    request.rootUid = rootUID
    request.treeID = treeID
    let _ = try self.callAndTranslateErrors(self.stub.refresh_subtree_stats(request), "enqueueRefreshSubtreeStatsTask")
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
    let opType = UserOpType(rawValue: response.userOp.opType)!

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
      NSLog("[\(treeID)] DEBUG From gRPC: \(filterCriteria)")
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
    if SUPER_DEBUG_ENABLED {
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
    if SUPER_DEBUG_ENABLED {
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

  private func callAndTranslateErrors<Req, Res>(_ call: UnaryCall<Req, Res>, _ rpcName: String) throws -> Res {
    do {
      NSLog("INFO  Calling gRPC: \(rpcName)")
      return try call.response.wait()
    } catch is NIOConnectionError {
      self.grpcConnectionDown()
      throw OutletError.grpcConnectionDown("RPC '\(rpcName)' failed: connection refused")
    } catch {
      // General failure. Maybe server internal error, or bad data, or something else
      throw OutletError.grpcFailure("RPC '\(rpcName)' failed: \(error)")
    }
  }

  private func grpcConnectionDown() {
    if self.isConnected {
      self.backendConnectionState.isConnected = false
      NSLog("INFO  gRPC connection is DOWN!")
      self.app.grpcDidGoDown()
    }
  }

  private func grpcConnectionRestored() {
    if !self.isConnected {
      self.backendConnectionState.isConnected = true
      NSLog("INFO  gRPC connection is UP!")
      self.backendConnectionState.conecutiveStreamFailCount = 0  // reset failure count
      self.app.grpcDidGoUp()
    }
  }

}
