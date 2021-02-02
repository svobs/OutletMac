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

/**
 CLASS NullBackend

 Should be used only for testing & previews
 */
class NullBackend: OutletBackend {
  func getConfig(_ configKey: String, defaultVal: String?) throws -> String {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func putConfig(_ configKey: String, _ configVal: String) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getConfigList(_ configKeyList: [String]) throws -> [String : String] {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func putConfigList(_ configDict: [String : String]) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getIntConfig(_ configKey: String, defaultVal: Int?) throws -> Int {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getNodeForUID(uid: UID, treeType: TreeType?) throws -> Node? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getNodeForLocalPath(fullPath: String) throws -> Node? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func nextUID() throws -> UID {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")  }

  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func startSubtreeLoad(treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getOpExecutionPlayState() throws -> Bool {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getChildList(parent: Node, treeID: String?, filterCriteria: FilterCriteria?) throws -> [Node] {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [Node] {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func createDisplayTreeForGDriveSelect() throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func createDisplayTreeFromConfig(treeID: String, isStartup: Bool) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func createDisplayTreeFromSPID(treeID: String, spid: SinglePathNodeIdentifier) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func createDisplayTreeFromUserPath(treeID: String, userPath: String) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func createExistingDisplayTree(treeID: String, treeDisplayMode: TreeDisplayMode) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func requestDisplayTree(request: DisplayTreeRequest) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func dropDraggedNodes(srcTreeID: String, srcSNList: [SPIDNodePair], isInto: Bool, dstTreeID: String, dstSN: SPIDNodePair) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [SPIDNodePair], selectedChangeListRight: [SPIDNodePair]) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func enqueueRefreshSubtreeStatsTask(rootUID: UID, treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getLastPendingOp(nodeUID: UID) throws -> UserOp? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func downloadFileFromGDrive(nodeUID: UID, requestorID: String) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func deleteSubtree(nodeUIDList: [UID]) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func getFilterCriteria(treeID: String) throws -> FilterCriteria? {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }

  func updateFilterCriteria(treeID: String, filterCriteria: FilterCriteria) throws {
    throw OutletError.invalidOperation("Cannot call NullBackend methods")
  }


}
