//
//  Backend.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//  Copyright © 2021 Ibotta. All rights reserved.
//

protocol OutletBackend {
  func reportError(sender: String, msg: String, secondaryMsg: String?)
  func getNodeForUID(uid: UID, treeType: TreeType?) -> Node?
  func getNodeForLocalPath(fullPath: String) -> Node?
  func nextUID() -> UID
  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) -> UID?
  func startSubtreeLoad(treeID: String)
  func getOpExecutionPlayState() -> Bool
  func getChildList(parent: Node, treeID: String?, filterCriteria: FilterCriteria?) -> [Node]
  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) -> [Node]
  
  func createDisplayTreeForGDriveSelect() -> DisplayTree?
  func createDisplayTreeFromConfig(treeID: String, isStartup: Bool?) -> DisplayTree?
  func createDisplayTreeFromSPID(treeID: String, spid: SinglePathNodeIdentifier) -> DisplayTree?
  func createDisplayTreeFromUserPath(treeID: String, userPath: String) -> DisplayTree?
  func createExistingDisplayTree(treeID: String, treeDisplayMode: TreeDisplayMode) -> DisplayTree?
  func requestDisplayTree(request: DisplayTreeRequest) -> DisplayTree?
  
  func dropDraggedNodes(srcTreeID: String, srcSNList: [SPIDNodePair], isInto: Bool, dstTreeID: String, dstSN: SPIDNodePair)
  func startDiffTrees(treeIDLeft: String, treeIDRight: String) -> DiffResultTreeIDs
  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [SPIDNodePair], selectedChangeListRight: [SPIDNodePair])
  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: String)
  func enqueueRefreshSubtreeStatsTask(rootUID: UID, treeID: String)
  func getLastPendingOp(nodeUID: UID) -> UserOp?
  func downloadFileFromGDrive(nodeUID: UID, requestorID: String)
  func deleteSubtree(nodeUIDList: [UID])
}
