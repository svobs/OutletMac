//
//  GRPCConverter.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-15.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

/**
 CLASS GRPCConverter
 
 Converts Swift objects to and from GRPC messages
 */
class GRPCConverter {
  
  // Node
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼
  
//  static func optionalNodeFromGRPC(_ nodeContainer: ) throws -> Node {
//
//  }

  static func nodeFromGRPC(nodeGRPC: Outlet_Backend_Daemon_Grpc_Generated_Node) throws -> Node {
    let treeType: TreeType = TreeType(rawValue: nodeGRPC.treeType)!
    let nodeIdentifier: NodeIdentifier = try NodeIdentifierFactory.forAllValues(nodeGRPC.uid, treeType, nodeGRPC.pathList, mustBeSinglePath: false)
    
    var node: Node
    
    if let nodeType = nodeGRPC.nodeType {
       switch nodeType {
       case .gdriveFileMeta(let meta):
         let gdriveIdentifier = nodeIdentifier as! GDriveIdentifier
         let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
         node = GDriveFile(gdriveIdentifier, meta.parentUidList, trashed: trashed, googID: meta.googID, createTS: meta.createTs,
                           modifyTS: meta.modifyTs, name: meta.name, ownerUID: meta.ownerUid, driveID: meta.driveID, isShared: nodeGRPC.isShared,
                           sharedByUserUID: meta.sharedByUserUid, syncTS: meta.syncTs, version: meta.version, md5: meta.md5,
                           mimeTypeUID: meta.mimeTypeUid, sizeBytes: meta.sizeBytes)
       case .gdriveFolderMeta(let meta):
         let gdriveIdentifier = nodeIdentifier as! GDriveIdentifier
         let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
         node = GDriveFolder(gdriveIdentifier, meta.parentUidList, trashed: trashed, googID: meta.googID, createTS: meta.createTs,
                             modifyTS: meta.modifyTs, name: meta.name, ownerUID: meta.ownerUid, driveID: meta.driveID, isShared:
                              nodeGRPC.isShared, sharedByUserUID: meta.sharedByUserUid, syncTS: meta.syncTs,
                             allChildrenFetched: meta.allChildrenFetched)
         try GRPCConverter.dirMetaFromGRPC(node, meta.dirMeta)
       case .localDirMeta(let meta):
         let localNodeIdentifier = nodeIdentifier as! LocalNodeIdentifier
         let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
         node = LocalDirNode(localNodeIdentifier, meta.parentUid, trashed, isLive: meta.isLive)
         try GRPCConverter.dirMetaFromGRPC(node, meta.dirMeta)
       case .localFileMeta(let meta):
        let localNodeIdentifier = nodeIdentifier as! LocalNodeIdentifier
        let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
        node = LocaFileNode(localNodeIdentifier, meta.parentUid, trashed: trashed, isLive: meta.isLive, md5: meta.md5, sha256: meta.sha256, sizeBytes: meta.sizeBytes, syncTS: meta.syncTs, modifyTS: meta.modifyTs, changeTS: meta.changeTs)
       case .containerMeta(let meta):
         node = ContainerNode(nodeIdentifier)
        try GRPCConverter.dirMetaFromGRPC(node, meta.dirMeta)
       case .categoryMeta(let meta):
         let opType = UserOpType(rawValue: meta.opType)!
         node = CategoryNode(nodeIdentifier, opType)
         try GRPCConverter.dirMetaFromGRPC(node, meta.dirMeta)
       case .rootTypeMeta(let meta):
         node = RootTypeNode(nodeIdentifier)
         try GRPCConverter.dirMetaFromGRPC(node, meta.dirMeta)
       }
    }
    
    node.icon = IconId(rawValue: nodeGRPC.iconID)!
    
    if nodeGRPC.decoratorNid > 0 {
      assert(nodeGRPC.decoratorParentNid > 0, "No parent_nid for decorator node! (decorator_nid=\(nodeGRPC.decoratorNid)")
      node = DecoNode.decorate(node, nodeGRPC.decoratorNid, nodeGRPC.decoratorParentNid)
    }
  }
  
  static func dirMetaFromGRPC(_ node: Node, _ dirMeta: Outlet_Backend_Daemon_Grpc_Generated_DirMeta) throws -> Void {
    // TODO
  }
  
  static func spidToGRPC(spid: SPID, spidGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) throws -> Void {
    // TODO
  }
  
  static func snFromGRPC(_ snGRPC: Outlet_Backend_Daemon_Grpc_Generated_SPIDNodePair) throws -> SPIDNodePair {
    let node: Node = try GRPCConverter.nodeFromGRPC(nodeGRPC: snGRPC.node)
    let spid: SinglePathNodeIdentifier = try GRPCConverter.spidFromGRPC(spidGRPC: snGRPC.spid)
    return SPIDNodePair(spid: spid, node: node)
  }
  
  static func spidFromGRPC(spidGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) throws -> SinglePathNodeIdentifier {
    let nodeIdentifier = try GRPCConverter.nodeIdentifierFromGRPC(spidGRPC)
    return nodeIdentifier as! SinglePathNodeIdentifier
  }
  
  static func nodeIdentifierFromGRPC(_ spidGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier) throws -> NodeIdentifier {
    let treeType: TreeType = TreeType(rawValue: spidGRPC.treeType)!
    return try NodeIdentifierFactory.forAllValues(spidGRPC.uid, treeType, spidGRPC.pathList, mustBeSinglePath: spidGRPC.isSinglePath)
  }
  
  static func nodeIdentifierToGRPC(nodeIdentifier: NodeIdentifier, nodeIdentifierGRPC: Outlet_Backend_Daemon_Grpc_Generated_NodeIdentifier)
      throws -> Void {
    // TODO
  }
  
  static func displayTreeUiStateFromGRPC(_ stateGRPC: Outlet_Backend_Daemon_Grpc_Generated_DisplayTreeUiState) throws -> DisplayTreeUiState {
    let rootSn: SPIDNodePair = try GRPCConverter.snFromGRPC(stateGRPC.rootSn)
    return DisplayTreeUiState(treeId: stateGRPC.treeID, rootSN: rootSn, rootExists: stateGRPC.rootExists)
  }
}
