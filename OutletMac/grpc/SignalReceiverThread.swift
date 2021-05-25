//
//  SingalReceiverThread.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-31.
//

let SLEEP_PERIOD_SEC: Double = 3

import Foundation

class SignalReceiverThread: Thread {
  let grpcClient: OutletGRPCClient

  init(_ grpcClient: OutletGRPCClient) {
    self.grpcClient = grpcClient
  }

  override func main() {
    while !self.isCancelled {
      // This will return only if there's an error (usually connection lost):
      self.grpcClient.receiveServerSignals()

      while !grpcClient.isConnected && !self.isCancelled {
        // TODO: send ping to indicate recovery from connection failure
        NSLog("INFO  Will retry signal stream in \(SLEEP_PERIOD_SEC) sec...")
        Thread.sleep(forTimeInterval: SLEEP_PERIOD_SEC)
        NSLog("DEBUG SignalReceiverThread looping (count: \(grpcClient.conecutiveStreamFailCount))")
      }
    }
  }
}
