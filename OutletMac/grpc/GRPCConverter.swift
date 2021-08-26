//
//  GRPCConverter.swift
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
  weak var backend: OutletBackend! = nil

  // Node
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func nodeToGRPC(_ node: Node) throws -> Outlet_Backend_Agent_Grpc_Generated_Node {
    NSLog("DEBUG Converting to gRPC: \(node)")
    var grpc = Outlet_Backend_Agent_Grpc_Generated_Node()
    // NodeIdentifier fields:
    grpc.nodeIdentifier = try self.nodeIdentifierToGRPC(node.nodeIdentifier)

    // Node common fields:
    grpc.trashed = node.trashed.rawValue
    grpc.isShared = node.isShared
    if let icon = node.customIcon {
      grpc.iconID = icon.rawValue
    }

    if let nonexistentDirNode = node as? NonexistentDirNode {
      grpc.nonexistentDirMeta = Outlet_Backend_Agent_Grpc_Generated_NonexistentDirMeta()
      grpc.nonexistentDirMeta.name = nonexistentDirNode.name
    } else if let containerNode = node as? ContainerNode {
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
        grpc.gdriveFolderMeta.dirMeta = try self.dirMetaToGRPC(node.getDirStats())
        assert(node is GDriveFolder, "Node has isDir=true but is not GDriveFolder: \(node)")
        let gnode = node as! GDriveFolder
        grpc.gdriveFolderMeta.allChildrenFetched = gnode.isAllChildrenFetched

        // GDriveNode common fields
        grpc.gdriveFolderMeta.googID = gnode.googID ?? ""
        grpc.gdriveFolderMeta.name = gnode.name
        grpc.gdriveFolderMeta.ownerUid = gnode.ownerUID
        grpc.gdriveFolderMeta.sharedByUserUid = gnode.sharedByUserUID ?? 0
        grpc.gdriveFolderMeta.driveID = gnode.driveID ?? ""
        grpc.gdriveFolderMeta.parentUidList = gnode.parentList
        grpc.gdriveFolderMeta.syncTs = gnode.syncTS ?? 0
        grpc.gdriveFolderMeta.modifyTs = gnode.modifyTS ?? 0
        grpc.gdriveFolderMeta.createTs = gnode.createTS ?? 0

      } else {  // GDrive File
        assert(node.isFile, "Expected node to be File type: \(node)")
        assert(node is GDriveFile, "Node has isDir=false but is not GDriveFile: \(node)")
        let gnode = node as! GDriveFile
        grpc.gdriveFileMeta = Outlet_Backend_Agent_Grpc_Generated_GDriveFileMeta()
        grpc.gdriveFileMeta.md5 = gnode.md5 ?? ""
        grpc.gdriveFileMeta.version = gnode.version ?? 0 // NOTE: may need to investigate if we ever use the version field
        grpc.gdriveFileMeta.sizeBytes = gnode.sizeBytes ?? 0 // FIXME! Null !== 0
        grpc.gdriveFileMeta.mimeTypeUid = gnode.mimeTypeUID // mimeType: 0 == null

        // GDriveNode common fields
        grpc.gdriveFileMeta.googID = gnode.googID ?? ""
        grpc.gdriveFileMeta.name = gnode.name
        grpc.gdriveFileMeta.ownerUid = gnode.ownerUID
        grpc.gdriveFileMeta.sharedByUserUid = gnode.sharedByUserUID ?? 0
        grpc.gdriveFileMeta.driveID = gnode.driveID ?? ""
        grpc.gdriveFileMeta.parentUidList = gnode.parentList
        grpc.gdriveFileMeta.syncTs = gnode.syncTS ?? 0
        grpc.gdriveFileMeta.modifyTs = gnode.modifyTS ?? 0
        grpc.gdriveFileMeta.createTs = gnode.createTS ?? 0
      }
    }

    return grpc
  }

  func nodeFromGRPC(_ nodeGRPC: Outlet_Backend_Agent_Grpc_Generated_Node) throws -> Node {
    let nodeIdentifier: NodeIdentifier = try self.nodeIdentifierFromGRPC(nodeGRPC.nodeIdentifier)

    var node: Node

    if let nodeType = nodeGRPC.nodeType {
      switch nodeType {
        case .gdriveFileMeta(let metaGRPC):
          let gdriveIdentifier = nodeIdentifier as! GDriveIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          let googID = metaGRPC.googID == "" ? nil : metaGRPC.googID
          let md5 = metaGRPC.md5 == "" ? nil : metaGRPC.md5
          let sizeBytes = metaGRPC.sizeBytes == 0 ? nil : metaGRPC.sizeBytes
          let modifyTs = metaGRPC.modifyTs == 0 ? nil : metaGRPC.modifyTs
          let createTs = metaGRPC.createTs == 0 ? nil : metaGRPC.createTs
          let syncTs = metaGRPC.syncTs == 0 ? nil : metaGRPC.syncTs
          let sharedByUserUid = metaGRPC.sharedByUserUid == 0 ? nil : metaGRPC.sharedByUserUid
          let driveId = metaGRPC.driveID == "" ? nil : metaGRPC.driveID
          node = GDriveFile(gdriveIdentifier, metaGRPC.parentUidList, trashed: trashed, googID: googID, createTS: createTs,
                            modifyTS: modifyTs, name: metaGRPC.name, ownerUID: metaGRPC.ownerUid, driveID: driveId, isShared: nodeGRPC.isShared,
                            sharedByUserUID: sharedByUserUid, syncTS: syncTs, version: metaGRPC.version, md5: md5,
                            mimeTypeUID: metaGRPC.mimeTypeUid, sizeBytes: sizeBytes)
        case .gdriveFolderMeta(let metaGRPC):
          let gdriveIdentifier = nodeIdentifier as! GDriveIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          let googID = metaGRPC.googID == "" ? nil : metaGRPC.googID
          let modifyTs = metaGRPC.modifyTs == 0 ? nil : metaGRPC.modifyTs
          let createTs = metaGRPC.createTs == 0 ? nil : metaGRPC.createTs
          let syncTs = metaGRPC.syncTs == 0 ? nil : metaGRPC.syncTs
          let sharedByUserUid = metaGRPC.sharedByUserUid == 0 ? nil : metaGRPC.sharedByUserUid
          let driveId = metaGRPC.driveID == "" ? nil : metaGRPC.driveID
          node = GDriveFolder(gdriveIdentifier, metaGRPC.parentUidList, trashed: trashed, googID: googID, createTS: createTs,
                              modifyTS: modifyTs, name: metaGRPC.name, ownerUID: metaGRPC.ownerUid, driveID: driveId, isShared:
                                nodeGRPC.isShared, sharedByUserUID: sharedByUserUid, syncTS: syncTs,
                              allChildrenFetched: metaGRPC.allChildrenFetched)
          let dirStats = try self.dirMetaFromGRPC(metaGRPC.dirMeta)
          node.setDirStats(dirStats)
        case .localDirMeta(let metaGRPC):
          let localNodeIdentifier = nodeIdentifier as! LocalNodeIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          node = LocalDirNode(localNodeIdentifier, metaGRPC.parentUid, trashed, isLive: metaGRPC.isLive)
          let dirStats = try self.dirMetaFromGRPC(metaGRPC.dirMeta)
          node.setDirStats(dirStats)
        case .localFileMeta(let metaGRPC):
          let localNodeIdentifier = nodeIdentifier as! LocalNodeIdentifier
          let trashed = TrashStatus(rawValue: nodeGRPC.trashed)!
          let md5 = metaGRPC.md5 == "" ? nil : metaGRPC.md5
          let sha256 = metaGRPC.sha256 == "" ? nil : metaGRPC.sha256
          let sizeBytes = metaGRPC.sizeBytes == 0 ? nil : metaGRPC.sizeBytes
          let syncTs = metaGRPC.syncTs == 0 ? nil : metaGRPC.syncTs
          let modifyTs = metaGRPC.modifyTs == 0 ? nil : metaGRPC.modifyTs
          let changeTs = metaGRPC.changeTs == 0 ? nil : metaGRPC.changeTs
          node = LocaFileNode(localNodeIdentifier, metaGRPC.parentUid, trashed: trashed, isLive: metaGRPC.isLive, md5: md5, sha256: sha256,
                              sizeBytes: sizeBytes, syncTS: syncTs, modifyTS: modifyTs, changeTS: changeTs)
        case .containerMeta(let metaGRPC):
          node = ContainerNode(nodeIdentifier)
          let dirStats = try self.dirMetaFromGRPC(metaGRPC.dirMeta)
          node.setDirStats(dirStats)
        case .categoryMeta(let metaGRPC):
          let opType = UserOpType(rawValue: metaGRPC.opType)!
          node = CategoryNode(nodeIdentifier, opType)
          let dirStats = try self.dirMetaFromGRPC(metaGRPC.dirMeta)
          node.setDirStats(dirStats)
        case .rootTypeMeta(let metaGRPC):
          node = RootTypeNode(nodeIdentifier)
          let dirStats = try self.dirMetaFromGRPC(metaGRPC.dirMeta)
          node.setDirStats(dirStats)
      case .nonexistentDirMeta(let metaGRPC):
        node = NonexistentDirNode(nodeIdentifier, metaGRPC.name)
      }
    } else {
      throw OutletError.invalidState("gRPC Node is missing node_type!")
    }

    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG Converted from gRPC: \(node)")

      if node.isDir {
        let dirStatsStr = node.getDirStats() == nil ? "nil" : "\(node.getDirStats()!)"
        NSLog("DEBUG DirNode \(node.nodeIdentifier) has DirStats: \(dirStatsStr)")
      }
    }

    node.customIcon = IconID(rawValue: nodeGRPC.iconID)!

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

  func nodeIdentifierFromGRPC(_ grpc: Outlet_Backend_Agent_Grpc_Generated_NodeIdentifier) throws -> NodeIdentifier {
    try self.backend.nodeIdentifierFactory.forValues(grpc.uid, deviceUID: grpc.deviceUid, grpc.pathList, pathUID: grpc.pathUid, opType: grpc.opType,
            parentGUID: grpc.parentGuid)
  }

  func nodeIdentifierToGRPC(_ nodeIdentifier: NodeIdentifier) throws -> Outlet_Backend_Agent_Grpc_Generated_NodeIdentifier {
    var grpc = Outlet_Backend_Agent_Grpc_Generated_NodeIdentifier()
    grpc.uid = nodeIdentifier.nodeUID
    grpc.deviceUid = nodeIdentifier.deviceUID
    grpc.pathList = nodeIdentifier.pathList
    if let spid = nodeIdentifier as? SPID {
      grpc.pathUid = spid.pathUID
      if let parentGUID = spid.parentGUID {
        grpc.parentGuid = parentGUID
      }
    }
    if nodeIdentifier is ChangeTreeSPID {
      let changeTreeSPID = nodeIdentifier as! ChangeTreeSPID
      if let opType = changeTreeSPID.opType {
        grpc.opType = opType.rawValue
      } else {
        grpc.opType = GRPC_CHANGE_TREE_NO_OP
      }
    }
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
    return grpc
  }

  func snFromGRPC(_ snGRPC: Outlet_Backend_Agent_Grpc_Generated_SPIDNodePair) throws -> SPIDNodePair {
    let spid: SinglePathNodeIdentifier = try self.spidFromGRPC(spidGRPC: snGRPC.spid)
    let node = try self.nodeFromGRPC(snGRPC.node)
    return SPIDNodePair(spid: spid, node: node)
  }

  func snListFromGRPC(_ snGRPCList: [Outlet_Backend_Agent_Grpc_Generated_SPIDNodePair]) throws -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    for snGRPC in snGRPCList {
      snList.append(try self.snFromGRPC(snGRPC))
    }
    return snList
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


  func displayTreeUiStateFromGRPC(_ grpc: Outlet_Backend_Agent_Grpc_Generated_DisplayTreeUiState) throws -> DisplayTreeUiState {
    let rootSn: SPIDNodePair = try self.snFromGRPC(grpc.rootSn)
    let treeDisplayMode = TreeDisplayMode(rawValue: grpc.treeDisplayMode)!
    NSLog("DEBUG [\(grpc.treeID)] Got rootSN: \(rootSn)")
    // note: I have absolutely no clue why gRPC renames "hasCheckboxes" to "hasCheckboxes_p"
    return DisplayTreeUiState(treeID: grpc.treeID, rootSN: rootSn, rootExists: grpc.rootExists, offendingPath: grpc.offendingPath,
            needsManualLoad: grpc.needsManualLoad, treeDisplayMode: treeDisplayMode, hasCheckboxes: grpc.hasCheckboxes_p)
  }
}
