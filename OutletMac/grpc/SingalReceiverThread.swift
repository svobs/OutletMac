//
//  SingalReceiverThread.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-31.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class SignalReceiverThread: Thread {
  let grpcClient: OutletGRPCClient
  init(_ grpcClient: OutletGRPCClient) {
    self.grpcClient = grpcClient
  }

  override func main() {
    while self.isExecuting {
      do {
        try self.receiveSignals()
      } catch {
        fatalError("Receiving signals failed: \(error)")
      }
    }
  }

  func receiveSignals() throws {
    try self.grpcClient.receiveServerSignals()
  }
}
