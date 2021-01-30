//
//  Backend.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//  Copyright © 2021 Ibotta. All rights reserved.
//

protocol OutletBackend {
  func getConfig(_ configKey: String, defaultVal: String?) throws -> String
  func putConfig(_ configKey: String, _ configVal: String) throws
  func getConfigList(_ configKeyList: [String]) throws -> [String: String]
  func putConfigList(_ configDict: [String: String]) throws
  func getIntConfig(_ configKey: String, defaultVal: Int?) throws -> Int
  
//  func reportError(sender: String, msg: String, secondaryMsg: String?) throws
  func getNodeForUID(uid: UID, treeType: TreeType?) throws -> Node?
  func getNodeForLocalPath(fullPath: String) throws -> Node?
  func nextUID() throws -> UID
  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID?
  func startSubtreeLoad(treeID: String) throws
  func getOpExecutionPlayState() throws -> Bool
  func getChildList(parent: Node, treeID: String?, filterCriteria: FilterCriteria?) throws -> [Node]
  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [Node]
  
  func createDisplayTreeForGDriveSelect() throws -> DisplayTree?
  func createDisplayTreeFromConfig(treeID: String, isStartup: Bool) throws -> DisplayTree?
  func createDisplayTreeFromSPID(treeID: String, spid: SinglePathNodeIdentifier) throws -> DisplayTree?
  func createDisplayTreeFromUserPath(treeID: String, userPath: String) throws -> DisplayTree?
  func createExistingDisplayTree(treeID: String, treeDisplayMode: TreeDisplayMode) throws -> DisplayTree?
  func requestDisplayTree(request: DisplayTreeRequest) throws -> DisplayTree?
  
  func dropDraggedNodes(srcTreeID: String, srcSNList: [SPIDNodePair], isInto: Bool, dstTreeID: String, dstSN: SPIDNodePair) throws
  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs
  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [SPIDNodePair], selectedChangeListRight: [SPIDNodePair]) throws
  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: String) throws
  func enqueueRefreshSubtreeStatsTask(rootUID: UID, treeID: String) throws
  func getLastPendingOp(nodeUID: UID) throws -> UserOp?
  func downloadFileFromGDrive(nodeUID: UID, requestorID: String) throws
  func deleteSubtree(nodeUIDList: [UID]) throws
  func getFilterCriteria(treeID: String) throws -> FilterCriteria?
  func updateFilterCriteria(treeID: String, filterCriteria: FilterCriteria) throws
}
