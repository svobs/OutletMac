//
//  SingalReceiverThread.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-31.
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
        try self.grpcClient.receiveServerSignals()
      } catch {
        // not clear if we ever get here
        NSLog("ERROR Receiving signals failed: \(error)")
      }
      // TODO: give more thought to handling various "async" code paths
      loopCount += 1
      if loopCount > 3 {
        // TODO: handle error better. Thoughts:
        // 1. Cancel all gRPC requests
        // 2. Kill the trees in the UI
        // 3. Display a "connecting" indicator until reconnected
        // OR:
        // 1. Modal dialog which will auto-close when reconected, with option to quit app

        NSLog("SignalReceiverThread: max failures exceeded! Sleeping 3s")
        Thread.sleep(forTimeInterval: 3)
      }
      NSLog("DEBUG SignalReceiverThread looping (count: \(loopCount))")
    }
  }
}
