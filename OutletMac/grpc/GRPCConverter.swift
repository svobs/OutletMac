//
//  self.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-15.
//

import Foundation

/**
 CLASS GRPCConverter
 
 Converts Swift objects to and from GRPC messages
 Note on ordering of methods: TO comes before FROM
 */
class GRPCConverter {
  let backend: OutletBackend

  init(_ backend: OutletBackend) {
    self.backend = backend
  }

  // Node
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func nodeToGRPC(_ node: Node) throws -> Outlet_Backend_Agent_Grpc_Generated_Node {
    var grpc = Outlet_Backend_Agent_Grpc_Generated_Node()
    let nodeIdentifier: NodeIdentifier
    if node.isDecorator {
      grpc.decoratorNid = node.uid
      grpc.decoratorParentNid = node.parentList[0]

      if let decoNode = node as? DecoNode {
        nodeIdentifier = decoNode.nodeIdentifier
      } else {
        throw OutletError.invalidState("Expected to be a DecoNode: \(node)")
      }
    } else {
      nodeIdentifier = node.nodeIdentifier
    }

    // NodeIdentifier fields:
    grpc.uid = nodeIdentifier.uid
    grpc.deviceUid = nodeIdentifier.deviceUID
    grpc.pathList = nodeIdentifier.pathList

    // Node common fields:
    grpc.trashed = node.trashed.rawValue
    grpc.isShared = node.isShared
    if let icon = node.customIcon {
      grpc.iconID = icon.rawValue
    }

    if let containerNode = node as? ContainerNode {
      // ContainerNode or subclass
      if let catNode = containerNode as? CategoryNode {
        grpc.categoryMeta = Outlet_Backend_Agent_Grpc_Generated_CategoryNodeMeta()
        grpc.categoryMeta.opType = catNode.opType.rawValue
        grpc.categoryMeta.dirMeta = try self.dirMetaToGRPC(catNode.getDirStats())
      } else if let rootTypeNode = containerNode as? RootTypeNode {
        grpc.rootTypeMeta = Outlet_Backend_Agent_Grpc_Generated_RootTypeNodeMeta()
        grpc.rootTypeMeta.dirMeta = try self.dirMetaToGRPC(rootTypeNode.getDirStats())
      } else {
        // plain ContainerNode
        grpc.containerMeta = Outlet_Backend_Agent_Grpc_Generated_ContainerNodeMeta()
        grpc.containerMeta.dirMeta = try self.dirMetaToGRPC(containerNode.getDirStats())
      }
    } else if node.treeType == .LOCAL_DISK {
      if node.isDir {
        grpc.localDirMeta = Outlet_Backend_Agent_Grpc_Generated_LocalDirMeta()
        grpc.localDirMeta.dirMeta = try self.dirMetaToGRPC(node.getDirStats())
        grpc.localDirMeta.isLive = node.isLive
        grpc.localDirMeta.parentUid = try node.getSingleParent()
      } else {
        assert(node.isFile, "Expected node to be File type: \(node)")
        grpc.localFileMeta = Outlet_Backend_Agent_Grpc_Generated_LocalFileMeta()
        grpc.localFileMeta.sizeBytes = node.sizeBytes ?? 0
        grpc.localFileMeta.syncTs = node.syncTS ?? 0
        grpc.localFileMeta.modifyTs = node.modifyTS ?? 0
        grpc.localFileMeta.changeTs = node.changeTS ?? 0
        grpc.localFileMeta.isLive = node.isLive
        grpc.localFileMeta.md5 = node.md5 ?? ""
        grpc.localFileMeta.sha256 = node.sha256 ?? ""
        grpc.localFileMeta.parentUid = try node.getSingleParent()
      }
    } else if node.treeType == .GDRIVE {

      if node.isDir {  // GDrive Folder
        grpc.gdriveFolderMeta = Outlet_Backend_Agent_Grpc_Generated_GDriveFolderMeta()
        var meta = grpc.gdriveFolderMeta
        meta.dirMeta = try self.dirMetaToGRPC(node.getDirStats())
        if let gnode = node as? GDriveFolder {
          meta.allChildrenFetched = gnode.isAllChildrenFetched

          // GDriveNode common fields
          meta.googID = gnode.googID ?? ""
          meta.name = gnode.name
          meta.ownerUid = gnode.ownerUID
          meta.sharedByUserUid = gnode.sharedByUserUID ?? 0
          meta.driveID = gnode.driveID ?? ""
          meta.parentUidList = gnode.parentList
          meta.syncTs = gnode.syncTS ?? 0
          meta.modifyTs = gnode.modifyTS ?? 0
          meta.createTs = gnode.createTS ?? 0
        } else {
          throw OutletError.invalidState("Node has isDir=true but is not GDriveFolder: \(node)")
        }

      } else {  // GDrive File
        assert(node.isFile, "Expected node to be File type: \(node)")
        if let gnode = node as? GDriveFile {
          grpc.gdriveFileMeta = Outlet_Backend_Agent_Grpc_Generated_GDriveFileMeta()
          var meta = grpc.gdriveFileMeta
          meta.md5 = gnode.md5 ?? ""
          meta.version = gnode.version ?? 0 // NOTE: may need to investigate if we ever use the version field
          meta.sizeBytes = gnode.sizeBytes ?? 0 // FIXME! Null !== 0
          meta.mimeTypeUid = gnode.mimeTypeUID // mimeType: 0 == null

          // GDriveNode common fields
          meta.googID = gnode.googID ?? ""
          meta.name = gnode.name
          meta.ownerUid = gnode.ownerUID
          meta.sharedByUserUid = gnode.sharedByUserUID ?? 0
          meta.driveID = gnode.driveID ?? ""
          meta.parentUidList = gnode.parentList
          meta.syncTs = gnode.syncTS ?? 0
          meta.modifyTs = gnode.modifyTS ?? 0
          meta.createTs = gnode.createTS ?? 0
        } else {
          throw OutletError.invalidState("Node has isDir=false but is not GDriveFile: \(node)")
        }

      }
    }

    return grpc
  }

  func nodeFromGRPC(_ nodeGRPC: Outlet_Backend_Agent_Grpc_Generated_Node) throws -> Node {
    if nodeGRPC.deviceUid == 0 {
      // this can indicate that the entire node doesn't exist or is invalid
      throw OutletError.invalidState("GRPC node's deviceUID is invalid!")
    }
    let nodeIdentifier: NodeIdentifier = try self.backend.nodeIdentifierFactory.forValues(nodeGRPC.uid, deviceUID: nodeGRPC.deviceUid, nodeGRPC.pathList, mustBeSinglePath: false)

    var node: Node

    if let nodeType = nodeGRPC.nodeType {
      switch nodeType {
        case .gdriveFileMeta(let meta):
          let gdriveIdentifier = nodeIdentifier as! GDriveIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          let googID = meta.googID == "" ? nil : meta.googID
          let md5 = meta.md5 == "" ? nil : meta.md5
          let sizeBytes = meta.sizeBytes == 0 ? nil : meta.sizeBytes
          let modifyTs = meta.modifyTs == 0 ? nil : meta.modifyTs
          let createTs = meta.createTs == 0 ? nil : meta.createTs
          let syncTs = meta.syncTs == 0 ? nil : meta.syncTs
          let sharedByUserUid = meta.sharedByUserUid == 0 ? nil : meta.sharedByUserUid
          let driveId = meta.driveID == "" ? nil : meta.driveID
          node = GDriveFile(gdriveIdentifier, meta.parentUidList, trashed: trashed, googID: googID, createTS: createTs,
                            modifyTS: modifyTs, name: meta.name, ownerUID: meta.ownerUid, driveID: driveId, isShared: nodeGRPC.isShared,
                            sharedByUserUID: sharedByUserUid, syncTS: syncTs, version: meta.version, md5: md5,
                            mimeTypeUID: meta.mimeTypeUid, sizeBytes: sizeBytes)
        case .gdriveFolderMeta(let meta):
          let gdriveIdentifier = nodeIdentifier as! GDriveIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          let googID = meta.googID == "" ? nil : meta.googID
          let modifyTs = meta.modifyTs == 0 ? nil : meta.modifyTs
          let createTs = meta.createTs == 0 ? nil : meta.createTs
          let syncTs = meta.syncTs == 0 ? nil : meta.syncTs
          let sharedByUserUid = meta.sharedByUserUid == 0 ? nil : meta.sharedByUserUid
          let driveId = meta.driveID == "" ? nil : meta.driveID
          node = GDriveFolder(gdriveIdentifier, meta.parentUidList, trashed: trashed, googID: googID, createTS: createTs,
                              modifyTS: modifyTs, name: meta.name, ownerUID: meta.ownerUid, driveID: driveId, isShared:
                                nodeGRPC.isShared, sharedByUserUID: sharedByUserUid, syncTS: syncTs,
                              allChildrenFetched: meta.allChildrenFetched)
          let dirStats = try self.dirMetaFromGRPC(meta.dirMeta)
          node.setDirStats(dirStats)
        case .localDirMeta(let meta):
          let localNodeIdentifier = nodeIdentifier as! LocalNodeIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          node = LocalDirNode(localNodeIdentifier, meta.parentUid, trashed, isLive: meta.isLive)
          let dirStats = try self.dirMetaFromGRPC(meta.dirMeta)
          node.setDirStats(dirStats)
        case .localFileMeta(let meta):
          let localNodeIdentifier = nodeIdentifier as! LocalNodeIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          let md5 = meta.md5 == "" ? nil : meta.md5
          let sha256 = meta.sha256 == "" ? nil : meta.sha256
          let sizeBytes = meta.sizeBytes == 0 ? nil : meta.sizeBytes
          let syncTs = meta.syncTs == 0 ? nil : meta.syncTs
          let modifyTs = meta.modifyTs == 0 ? nil : meta.modifyTs
          let changeTs = meta.changeTs == 0 ? nil : meta.changeTs
          node = LocaFileNode(localNodeIdentifier, meta.parentUid, trashed: trashed, isLive: meta.isLive, md5: md5, sha256: sha256,
                              sizeBytes: sizeBytes, syncTS: syncTs, modifyTS: modifyTs, changeTS: changeTs)
        case .containerMeta(let meta):
          node = ContainerNode(nodeIdentifier)
          let dirStats = try self.dirMetaFromGRPC(meta.dirMeta)
          node.setDirStats(dirStats)
        case .categoryMeta(let meta):
          let opType = UserOpType(rawValue: meta.opType)!
          node = CategoryNode(nodeIdentifier, opType)
          let dirStats = try self.dirMetaFromGRPC(meta.dirMeta)
          node.setDirStats(dirStats)
        case .rootTypeMeta(let meta):
          node = RootTypeNode(nodeIdentifier)
          let dirStats = try self.dirMetaFromGRPC(meta.dirMeta)
          node.setDirStats(dirStats)
      }
    } else {
      throw OutletError.invalidState("gRPC Node is missing node_type!")
    }

    node.customIcon = IconID(rawValue: nodeGRPC.iconID)!

    if nodeGRPC.decoratorNid > 0 {
      assert(nodeGRPC.decoratorParentNid > 0, "No parent_nid for decorator node! (decorator_nid=\(nodeGRPC.decoratorNid)")
      node = DecoratorFactory.decorate(node, nodeGRPC.decoratorNid, nodeGRPC.decoratorParentNid)
    }

    return node
  }

  func dirMetaToGRPC(_ dirStats: DirectoryStats?) throws -> Outlet_Backend_Agent_Grpc_Generated_DirMeta {
    var grpc = Outlet_Backend_Agent_Grpc_Generated_DirMeta()
    if dirStats == nil {
      grpc.hasData_p = false
    } else {
      grpc.hasData_p = true
      grpc.fileCount = dirStats!.fileCount
      grpc.dirCount = dirStats!.dirCount
      grpc.trashedFileCount = dirStats!.trashedFileCount
      grpc.trashedDirCount = dirStats!.trashedDirCount
      grpc.sizeBytes = dirStats!.sizeBytes
      grpc.trashedBytes = dirStats!.trashedBytes
    }
    return grpc
  }


  func dirMetaFromGRPC(_ grpc: Outlet_Backend_Agent_Grpc_Generated_DirMeta) throws -> DirectoryStats? {
    if grpc.hasData_p {
      let dirStats = DirectoryStats()
      dirStats.fileCount = grpc.fileCount
      dirStats.dirCount = grpc.dirCount
      dirStats.trashedFileCount = grpc.trashedFileCount
      dirStats.trashedDirCount = grpc.trashedDirCount
      dirStats.sizeBytes = grpc.sizeBytes
      dirStats.trashedBytes = grpc.trashedBytes
      return dirStats
    } else {
      return nil
    }
  }

  // Node list
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func nodeListFromGRPC(_ nodeListGRPC: [Outlet_Backend_Agent_Grpc_Generated_Node]) throws -> [Node] {
    var convertedNodeList: [Node] = []
    for nodeGRPC in nodeListGRPC {
      convertedNodeList.append(try self.nodeFromGRPC(nodeGRPC))
    }
    return convertedNodeList
  }

  func nodeListToGRPC(_ nodeList: [Node]) throws -> [Outlet_Backend_Agent_Grpc_Generated_Node] {
    var nodeListGRPC: [Outlet_Backend_Agent_Grpc_Generated_Node] = []
    for node in nodeList {
      nodeListGRPC.append(try self.nodeToGRPC(node))
    }
    return nodeListGRPC
  }

  // NodeIdentifier
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func nodeIdentifierFromGRPC(_ spidGRPC: Outlet_Backend_Agent_Grpc_Generated_NodeIdentifier) throws -> NodeIdentifier {
    return try self.backend.nodeIdentifierFactory.forValues(spidGRPC.uid, deviceUID: spidGRPC.deviceUid, spidGRPC.pathList, mustBeSinglePath: spidGRPC.isSinglePath)
  }

  func nodeIdentifierToGRPC(_ nodeIdentifier: NodeIdentifier) throws -> Outlet_Backend_Agent_Grpc_Generated_NodeIdentifier {
    var grpc = Outlet_Backend_Agent_Grpc_Generated_NodeIdentifier()
    grpc.uid = nodeIdentifier.uid
    grpc.deviceUid = nodeIdentifier.deviceUID
    grpc.pathList = nodeIdentifier.pathList
    grpc.isSinglePath = nodeIdentifier.isSPID()
    return grpc
  }

  func spidFromGRPC(spidGRPC: Outlet_Backend_Agent_Grpc_Generated_NodeIdentifier) throws -> SinglePathNodeIdentifier {
    let nodeIdentifier = try self.nodeIdentifierFromGRPC(spidGRPC)
    return nodeIdentifier as! SinglePathNodeIdentifier
  }

  // SPIDNodePair
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func snToGRPC(_ sn: SPIDNodePair) throws -> Outlet_Backend_Agent_Grpc_Generated_SPIDNodePair {
    var grpc = Outlet_Backend_Agent_Grpc_Generated_SPIDNodePair()
    grpc.spid = try self.nodeIdentifierToGRPC(sn.spid)
    if sn.node != nil {
      grpc.node = try self.nodeToGRPC(sn.node!)
    }
    return grpc
  }

  func snFromGRPC(_ snGRPC: Outlet_Backend_Agent_Grpc_Generated_SPIDNodePair) throws -> SPIDNodePair {
    let spid: SinglePathNodeIdentifier = try self.spidFromGRPC(spidGRPC: snGRPC.spid)
    let node: Node?
    if snGRPC.hasNode {
      node = try self.nodeFromGRPC(snGRPC.node)
    } else {
      node = nil
    }
    return SPIDNodePair(spid: spid, node: node)
  }

  // FilterCriteria
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func filterCriteriaToGRPC(_ filterCriteria: FilterCriteria) throws -> Outlet_Backend_Agent_Grpc_Generated_FilterCriteria {
    var grpc = Outlet_Backend_Agent_Grpc_Generated_FilterCriteria()
    grpc.searchQuery = filterCriteria.searchQuery
    grpc.isTrashed = filterCriteria.isTrashed.rawValue
    grpc.isShared = filterCriteria.isShared.rawValue
    grpc.isIgnoreCase = filterCriteria.isIgnoreCase
    grpc.showSubtreesOfMatches = filterCriteria.showAncestors
    return grpc
  }

  func filterCriteriaFromGRPC(_ grpc: Outlet_Backend_Agent_Grpc_Generated_FilterCriteria) throws -> FilterCriteria {
    return FilterCriteria(searchQuery: grpc.searchQuery, isTrashed: Ternary(rawValue: grpc.isTrashed)!,
                          isShared: Ternary(rawValue: grpc.isShared)!, isIgnoreCase: grpc.isIgnoreCase,
                          showAncestors: grpc.showSubtreesOfMatches)
  }

  // DisplayTreeUiState
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼


  func displayTreeUiStateFromGRPC(_ stateGRPC: Outlet_Backend_Agent_Grpc_Generated_DisplayTreeUiState) throws -> DisplayTreeUiState {
    let rootSn: SPIDNodePair = try self.snFromGRPC(stateGRPC.rootSn)
    NSLog("Got rootSN: \(rootSn)")
    return DisplayTreeUiState(treeID: stateGRPC.treeID, rootSN: rootSn, rootExists: stateGRPC.rootExists)
  }
}
