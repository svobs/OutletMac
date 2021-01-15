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

typealias UID = Int64

let NULL_UID: UID = 0

enum OutletError: Error {
  case invalidOperation
}

class OutletGRPCClient {
  let stub: Outlet_Backend_Daemon_Grpc_Generated_OutletClient
  init(_ client: Outlet_Backend_Daemon_Grpc_Generated_OutletClient) {
    self.stub = client
  }
  
  /// Makes a `RouteGuide` client for a service hosted on "localhost" and listening on the given port.
  static func makeClient(host: String, port: Int) -> OutletGRPCClient {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
      try? group.syncShutdownGracefully()
    }

    let channel = ClientConnection.insecure(group: group)
      .connect(host: host, port: port)

    return OutletGRPCClient(Outlet_Backend_Daemon_Grpc_Generated_OutletClient(channel: channel))
  }
  
  func requestDisplayTree(_ request: DisplayTreeRequest) -> DisplayTree? {
    var grpcRequest = Outlet_Backend_Daemon_Grpc_Generated_RequestDisplayTree_Request()
    grpcRequest.isStartup = request.isStartup
    grpcRequest.treeID = request.treeId
    grpcRequest.userPath = request.userPath ?? ""
    
    GRPCConverter.fromNodeIdentifierToGRPC(spid: request.spid, grpcSPID: grpcRequest.spid)

    let call = self.stub.request_display_tree_ui_state(grpcRequest)

//    let response = try call.response.wait()
//    if (response.hasDisplayTreeUiState) {
//      let state: DisplayTreeUiState = GRPCConverter.toDisplayTreeUiStateFromGRPC(response.displayTreeUiState)

      return nil  // TODO
    }
  }

  /*
   def request_display_tree(self, request: DisplayTreeRequest) -> Optional[DisplayTree]:
       assert request.tree_id, f'No tree_id in: {request}'
       grpc_req = RequestDisplayTree_Request()
       grpc_req.is_startup = request.is_startup
       if request.tree_id:
           grpc_req.tree_id = request.tree_id
       grpc_req.return_async = request.return_async
       if request.user_path:
           grpc_req.user_path = request.user_path
       Converter.node_identifier_to_grpc(request.spid, grpc_req.spid)
       grpc_req.tree_display_mode = request.tree_display_mode

       response = self.grpc_stub.request_display_tree_ui_state(grpc_req)

       if response.HasField('display_tree_ui_state'):
           state = Converter.display_tree_ui_state_from_grpc(response.display_tree_ui_state)
           tree = state.to_display_tree(backend=self)
       else:
           tree = None
       logger.debug(f'Returning tree: {tree}')
       return tree

   */



class DisplayTree {
  let state: DisplayTreeUiState
  
  init(state: DisplayTreeUiState) {
    self.state = state
  }

}

/**
 Fat Microsoft-style struct encapsulating a bunch of params for request_display_tree()
 */
class DisplayTreeRequest {
  let treeId: String
  let returnAsync: Bool
  let userPath: String?
  let spid: SPID
  let isStartup: Bool
  let treeDisplayMode: TreeDisplayMode
  
  init(treeId: String, returnAsync: Bool, userPath: String?, spid: SPID, isStartup: Bool = false, treeDisplayMode: TreeDisplayMode = TreeDisplayMode.ONE_TREE_ALL_ITEMS) {
    self.treeId = treeId
    self.returnAsync = returnAsync
    self.userPath = userPath
    self.spid = spid
    self.isStartup = isStartup
    self.treeDisplayMode = treeDisplayMode
  }
}

class DisplayTreeUiState {
  let treeId: String
  let rootSN: SPIDNodePair
  let rootExists: Bool
  let offendingPath: String?
  let treeDisplayMode: TreeDisplayMode
  let hasCheckboxes: Bool
  let needsManualLoad: Bool
  
  init(treeId: String, rootSN: SPIDNodePair, rootExists: Bool, offendingPath: String? = nil, treeDisplayMode: TreeDisplayMode = TreeDisplayMode.ONE_TREE_ALL_ITEMS, hasCheckboxes: Bool = false) {
    self.treeId = treeId
    /**SPIDNodePair is needed to clarify the (albeit very rare) case where the root node resolves to multiple paths.
    Each display tree can only have one root path.*/
    self.rootSN = rootSN
    self.rootExists = rootExists
    self.offendingPath = offendingPath
    self.treeDisplayMode = treeDisplayMode
    self.hasCheckboxes = hasCheckboxes
    
    /**If True, the UI should display a "Load" button in order to kick off the backend data load.
    If False; the backend will automatically start loading in the background.*/
    self.needsManualLoad = false
  }

}
