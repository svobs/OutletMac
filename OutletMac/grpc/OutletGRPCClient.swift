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
  
  func requestDisplayTree(_ request: DisplayTreeRequest) throws -> DisplayTree? {
    var grpcRequest = Outlet_Backend_Daemon_Grpc_Generated_RequestDisplayTree_Request()
    grpcRequest.isStartup = request.isStartup
    grpcRequest.treeID = request.treeId
    grpcRequest.userPath = request.userPath ?? ""
    
    GRPCConverter.spidToGRPC(spid: request.spid, spidGRPC: grpcRequest.spid)

    let call = self.stub.request_display_tree_ui_state(grpcRequest)

    do {
      let response = try call.response.wait()
      if (response.hasDisplayTreeUiState) {
        let state: DisplayTreeUiState = try GRPCConverter.displayTreeUiStateFromGRPC(response.displayTreeUiState)

        return nil  // TODO
      }
    } catch {
      NSLog("RPC failed: \(error)")
      throw OutletError.grpcFailure
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

}
