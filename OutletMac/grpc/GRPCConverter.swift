//
//  GRPCConverter.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-15.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class GRPCConverter {
  
  static func fromNodeIdentifierToGRPC(spid: SPID, grpcSPID: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) -> Void {
    // TODO
  }
  
  static func toDisplayTreeUiStateFromGRPC(_ displayTreeUiState: Outlet_Backend_Daemon_Grpc_Generated_DisplayTreeUiState) -> DisplayTreeUiState {
    var state = DisplayTreeUiState()
    
    // TODO
    return state
  }
}
