//
//  GRPCConverter.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-15.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class GRPCConverter {
  
  static func snFromGRPC(_ snGRPC: Outlet_Backend_Daemon_Grpc_Generated_SPIDNodePair) throws -> SPIDNodePair {
    let node: Node = GRPCConverter.nodeFromGRPC(nodeGRPC: snGRPC.node)
    let spid: SinglePathNodeIdentifier = try GRPCConverter.spidFromGRPC(spidGRPC: snGRPC.spid)
    return SPIDNodePair(spid: spid, node: node)
  }
  
  static func nodeFromGRPC(nodeGRPC: Outlet_Backend_Daemon_Grpc_Generated_Node) -> Node {
    // TODO
  }
  
  static func spidToGRPC(spid: SPID, spidGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) -> Void {
    // TODO
  }
  
  static func spidFromGRPC(spidGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) throws -> SinglePathNodeIdentifier {
    let nodeIdentifier = try GRPCConverter.nodeIdentifierFromGRPC(spidGRPC)
    return nodeIdentifier as! SinglePathNodeIdentifier
  }
  
  static func nodeIdentifierFromGRPC(_ spidGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) throws -> NodeIdentifier {
    let treeType: TreeType = TreeType(rawValue: spidGRPC.treeType)!
    return try NodeIdentifierFactory.forAllValues(spidGRPC.uid, treeType, spidGRPC.pathList, mustBeSinglePath: spidGRPC.isSinglePath)
  }
  
  static func nodeIdentifierToGRPC(nodeIdentifier: NodeIdentifier, nodeIdentifierGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) -> Void {
    // TODO
  }
  
  static func displayTreeUiStateFromGRPC(_ stateGRPC: Outlet_Backend_Daemon_Grpc_Generated_DisplayTreeUiState) throws -> DisplayTreeUiState {
    let rootSn: SPIDNodePair = try GRPCConverter.snFromGRPC(stateGRPC.rootSn)
    return DisplayTreeUiState(treeId: stateGRPC.treeID, rootSN: rootSn, rootExists: stateGRPC.rootExists)
  }
}
