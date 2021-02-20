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
  var loopCount: Int = 0

  init(_ grpcClient: OutletGRPCClient) {
    self.grpcClient = grpcClient
  }

  override func main() {
    while self.isExecuting {
      do {
        try self.receiveSignals()
      } catch {
        // not clear if we ever get here
        NSLog("ERROR Receiving signals failed: \(error)")
      }
      // TODO: give more thought to handling various "async" code paths
      loopCount += 1
      if loopCount > 3 {
        // TODO: handle error better
        fatalError("SignalReceiverThread: max failures exceeded!")
      }
      NSLog("DEBUG SignalReceiverThread looping (count: \(loopCount))")
    }
  }

  func receiveSignals() throws {
    try self.grpcClient.receiveServerSignals()
  }
}
