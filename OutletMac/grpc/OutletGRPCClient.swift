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
  /// Makes a `RouteGuide` client for a service hosted on "localhost" and listening on the given port.
  static func makeClient(host: String, port: Int) -> Outlet_Backend_Daemon_Grpc_Generated_OutletClient {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
      try? group.syncShutdownGracefully()
    }

    let channel = ClientConnection.insecure(group: group)
      .connect(host: host, port: port)

    return Outlet_Backend_Daemon_Grpc_Generated_OutletClient(channel: channel)
  }
}
