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
          let createTs = metaGRPC.createTs == 0 ? nil : metaGRPC.createTs
          let modifyTs = metaGRPC.modifyTs == 0 ? nil : metaGRPC.modifyTs
          let changeTs = metaGRPC.changeTs == 0 ? nil : metaGRPC.changeTs
          node = LocaFileNode(localNodeIdentifier, metaGRPC.parentUid, trashed: trashed, isLive: metaGRPC.isLive, md5: md5, sha256: sha256,
                              sizeBytes: sizeBytes, syncTS: syncTs, createTS: createTs, modifyTS: modifyTs, changeTS: changeTs)
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

      node.customIcon = IconID(rawValue: nodeGRPC.iconID)
    } else {
      throw OutletError.invalidState("gRPC Node is missing node_type!")
    }

    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG Converted from gRPC: \(node)")

      if node.isDir {
        let dirStatsStr = node.getDirStats() == nil ? "nil" : "\(node.getDirStats()!)"
        let nodeClassName: String = String(describing: type(of: node))
        NSLog("DEBUG \(nodeClassName) \(node.nodeIdentifier) has DirStats: \(dirStatsStr), etc='\(node.etc)'")
      }
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
    if let spid = nodeIdentifier as? SinglePathNodeIdentifier {
      if spid.parentGUID == spid.guid {
        throw OutletError.invalidState("SPID's GUID is the same as its parent GUID: \(spid)")
      }
      return spid
    } else {
      NSLog("""
            ERROR Cannot be cast to SPID: \(nodeIdentifier) (values: uid=\(spidGRPC.uid), 
            deviceUID=\(spidGRPC.deviceUid), pathList=\(spidGRPC.pathList), pathUID: \(spidGRPC.pathUid), opType: \(spidGRPC.opType), 
            parentGUID: \(spidGRPC.parentGuid))
            """)
      throw OutletError.invalidState("Server sent us invalid data: expected a SPID but got a NodeIdentifier: \(nodeIdentifier)")
    }
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

  // Device
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func deviceToGRPC(_ device: Device) -> Outlet_Backend_Agent_Grpc_Generated_Device {
    fatalError("Not implemented: deviceToGRPC()")
  }

  func deviceFromGRPC(_ deviceGRPC: Outlet_Backend_Agent_Grpc_Generated_Device) throws -> Device {
    guard let treeType: TreeType = TreeType(rawValue: deviceGRPC.treeType) else {
      fatalError("Could not resolve TreeType from int value: \(deviceGRPC.treeType)")
    }
    return Device(device_uid: deviceGRPC.deviceUid, long_device_id: deviceGRPC.longDeviceID, treeType: treeType, friendlyName: deviceGRPC.friendlyName)
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

  // Tree Context Menu
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func actionTypeFromGRPC(_ grpcActionID: UInt32) -> ActionType {
    if let actionID = ActionID(rawValue: grpcActionID) {
      return ActionType.BUILTIN(actionID)
    } else {
      return .CUSTOM(grpcActionID)
    }
  }

  func menuItemListFromGRPC(_ grpcList: [Outlet_Backend_Agent_Grpc_Generated_TreeContextMenuItem]) throws -> [MenuItemMeta] {
    var menuItemList: [MenuItemMeta] = []

    for grpcItem in grpcList {
      menuItemList.append(try self.menuItemFromGRPC(grpcItem))
    }
    return menuItemList
  }

  func menuItemFromGRPC(_ grpc: Outlet_Backend_Agent_Grpc_Generated_TreeContextMenuItem) throws -> MenuItemMeta {
    guard let itemType = MenuItemType.init(rawValue: grpc.itemType) else {
      throw OutletError.invalidState("Bad value received from gRPC: MenuItemType (\(grpc.itemType)) is invalid!")
    }
    let actionType: ActionType = self.actionTypeFromGRPC(grpc.actionID)
    let item = MenuItemMeta(itemType: itemType, title: grpc.title, actionType: actionType)
    for submenuItem in grpc.submenuItemList {
      item.submenuItemList.append(try self.menuItemFromGRPC(submenuItem))
    }
    for guid in grpc.targetGuidList {
      item.targetGUIDList.append(guid)
    }
    return item
  }

  func treeActionFromGRPC(_ grpc: Outlet_Backend_Agent_Grpc_Generated_TreeAction) throws -> TreeAction {
    let actionType: ActionType = self.actionTypeFromGRPC(grpc.actionID)

    var targetGUIDList: [GUID] = []
    for guid in grpc.targetGuidList {
      targetGUIDList.append(guid)
    }

    var targetNodeList: [Node] = []
    for nodeGRPC in grpc.targetNodeList {
      targetNodeList.append(try self.nodeFromGRPC(nodeGRPC))
    }

    return TreeAction(grpc.treeID, actionType, targetGUIDList, targetNodeList)
  }

  func treeActionToGRPC(_ treeAction: TreeAction) throws -> Outlet_Backend_Agent_Grpc_Generated_TreeAction {
    var treeActionGRPC = Outlet_Backend_Agent_Grpc_Generated_TreeAction()
    treeActionGRPC.actionID = treeAction.getActionID()
    treeActionGRPC.treeID = treeAction.treeID
    treeActionGRPC.targetGuidList = treeAction.targetGUIDList
    for node in treeAction.targetNodeList {
      treeActionGRPC.targetNodeList.append(try self.nodeToGRPC(node))
    }
    return treeActionGRPC
  }

  func signalArgDictFromGRPC(_ signal: Signal, _ signalGRPC: Outlet_Backend_Agent_Grpc_Generated_SignalMsg) throws -> [String: Any] {
    var argDict: [String: Any] = [:]

    switch signal {
      case .EXECUTE_ACTION:
        var actionList: [TreeAction] = []
        for actionGRPC in signalGRPC.treeActionRequest.actionList {
          actionList.append(try self.treeActionFromGRPC(actionGRPC))
        }
        argDict["action_list"] = actionList
      case .DISPLAY_TREE_CHANGED, .GENERATE_MERGE_TREE_DONE:
        let displayTreeUiState = try self.displayTreeUiStateFromGRPC(signalGRPC.displayTreeUiState)
        let tree: DisplayTree = displayTreeUiState.toDisplayTree(backend: self.backend)
        argDict["tree"] = tree
      case .DIFF_TREES_DONE, .DIFF_TREES_CANCELLED:
        let displayTreeUiStateL = try self.displayTreeUiStateFromGRPC(signalGRPC.dualDisplayTree.leftTree)
        let treeL: DisplayTree = displayTreeUiStateL.toDisplayTree(backend: self.backend)
        argDict["tree_left"] = treeL
        let displayTreeUiStateR = try self.displayTreeUiStateFromGRPC(signalGRPC.dualDisplayTree.rightTree)
        let treeR: DisplayTree = displayTreeUiStateR.toDisplayTree(backend: self.backend)
        argDict["tree_right"] = treeR
      case .OP_EXECUTION_PLAY_STATE_CHANGED:
        argDict["is_enabled"] = signalGRPC.playState.isEnabled
      case .TOGGLE_UI_ENABLEMENT:
        argDict["enable"] = signalGRPC.uiEnablement.enable
      case .SET_SELECTED_ROWS:
        var guidSet = Set<GUID>()
        for guid in signalGRPC.guidSet.guidSet {
          guidSet.insert(guid)
        }
        argDict["selected_rows"] = guidSet
      case .ERROR_OCCURRED:
        argDict["msg"] = signalGRPC.errorOccurred.msg
        argDict["secondary_msg"] = signalGRPC.errorOccurred.secondaryMsg
      case .NODE_UPSERTED, .NODE_REMOVED:
        argDict["sn"] = try self.snFromGRPC(signalGRPC.sn)
      case .SUBTREE_NODES_CHANGED:
        argDict["subtree_root_spid"] = try self.spidFromGRPC(spidGRPC: signalGRPC.subtree.subtreeRootSpid)
        argDict["upserted_sn_list"] = try self.snListFromGRPC(signalGRPC.subtree.upsertedSnList)
        argDict["removed_sn_list"] = try self.snListFromGRPC(signalGRPC.subtree.removedSnList)
      case .TREE_LOAD_STATE_UPDATED:
        argDict["tree_load_state"] = TreeLoadState(rawValue: signalGRPC.treeLoadUpdate.loadStateInt)
        try self.convertStatsAndStatus(statsUpdate: signalGRPC.treeLoadUpdate.statsUpdate, argDict: &argDict)
      case .DOWNLOAD_FROM_GDRIVE_DONE:
        argDict["filename"] = signalGRPC.downloadMsg.filename
      case .STATS_UPDATED:
        try self.convertStatsAndStatus(statsUpdate: signalGRPC.statsUpdate, argDict: &argDict)
      case .DEVICE_UPSERTED:
        argDict["device"] = try self.deviceFromGRPC(signalGRPC.device)
      case .BATCH_FAILED:
        argDict["batch_uid"] = signalGRPC.batchFailed.batchUid
        argDict["msg"] = signalGRPC.batchFailed.msg
        argDict["secondary_msg"] = signalGRPC.batchFailed.secondaryMsg
      default:
        break
    }
    argDict["signal"] = signal

    return argDict
  }

  private func convertStatsAndStatus(statsUpdate: Outlet_Backend_Agent_Grpc_Generated_StatsUpdate, argDict: inout [String: Any]) throws {
    argDict["status_msg"] = statsUpdate.statusMsg

    var dirStatsByUidDict: [UID:DirectoryStats] = [:]
    for dirMetaUpdate in statsUpdate.dirMetaByUidList {
      dirStatsByUidDict[dirMetaUpdate.uid] = try self.dirMetaFromGRPC(dirMetaUpdate.dirMeta)
    }
    argDict["dir_stats_dict_by_uid"] = dirStatsByUidDict

    var dirStatsByGuidDict: [GUID:DirectoryStats] = [:]
    for dirMetaUpdate in statsUpdate.dirMetaByGuidList {
      dirStatsByGuidDict[dirMetaUpdate.guid] = try self.dirMetaFromGRPC(dirMetaUpdate.dirMeta)
    }
    argDict["dir_stats_dict_by_guid"] = dirStatsByGuidDict
  }

}
