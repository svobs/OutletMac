//
//  Backend.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI

protocol OutletBackend: HasLifecycle {
  func getConfig(_ configKey: String, defaultVal: String?) throws -> String
  func putConfig(_ configKey: String, _ configVal: String) throws
  func getConfigList(_ configKeyList: [String]) throws -> [String: String]
  func putConfigList(_ configDict: [String: String]) throws
  func getIntConfig(_ configKey: String, defaultVal: Int?) throws -> Int
  func getBoolConfig(_ configKey: String, defaultVal: Bool?) throws -> Bool
  func getIcon(_ iconID: IconId) throws -> NSImage?
  
  //  func reportError(sender: String, msg: String, secondaryMsg: String?) throws
  func getNodeForUID(uid: UID, treeType: TreeType?) throws -> Node?
  func getNodeForLocalPath(fullPath: String) throws -> Node?
  func nextUID() throws -> UID
  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID?
  func startSubtreeLoad(treeID: String) throws
  func getOpExecutionPlayState() throws -> Bool
  func getChildList(parentUID: UID, treeID: String?, maxResults: UInt32?) throws -> [Node]
  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [Node]
  func getRowsOfInterest(treeID: String) throws -> RowsOfInterest
  func setSelectedRowSet(_ selected: Set<UID>, _ treeID: String) throws
  func removeExpandedRow(_ rowUID: UID, _ treeID: String) throws
  
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
  func getFilterCriteria(treeID: String) throws -> FilterCriteria
  func updateFilterCriteria(treeID: String, filterCriteria: FilterCriteria) throws
}

/**
 Workaround to add default params.
 This may be bad practice. See note at bottom of https://medium.com/@georgetsifrikas/swift-protocols-with-default-values-b7278d3eef22
 */
extension OutletBackend {
  func getConfig(_ configKey: String) throws -> String {
    return try getConfig(configKey, defaultVal: nil)
  }

  func getIntConfig(_ configKey: String) throws -> Int {
    return try getIntConfig(configKey, defaultVal: nil)
  }

  func getBoolConfig(_ configKey: String) throws -> Bool {
    return try getBoolConfig(configKey, defaultVal: nil)
  }
}

/**
 CLASS MockBackend

 Should be used only for testing & previews
 */
class MockBackend: OutletBackend {
  let dipatcher: SignalDispatcher
  init(_ d: SignalDispatcher? = nil) {
    self.dipatcher = d ?? SignalDispatcher()
  }

  func start() throws {
  }

  func shutdown() throws {
  }

  func getConfig(_ configKey: String, defaultVal: String?) throws -> String {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func putConfig(_ configKey: String, _ configVal: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getConfigList(_ configKeyList: [String]) throws -> [String : String] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func putConfigList(_ configDict: [String : String]) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getIntConfig(_ configKey: String, defaultVal: Int?) throws -> Int {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getBoolConfig(_ configKey: String, defaultVal: Bool?) throws -> Bool {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getIcon(_ iconID: IconId) throws -> NSImage? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getNodeForUID(uid: UID, treeType: TreeType?) throws -> Node? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getNodeForLocalPath(fullPath: String) throws -> Node? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func nextUID() throws -> UID {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")  }

  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func startSubtreeLoad(treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getOpExecutionPlayState() throws -> Bool {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getChildList(parentUID: UID, treeID: String?, maxResults: UInt32?) throws -> [Node] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getAncestorList(spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [Node] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getRowsOfInterest(treeID: String) throws -> RowsOfInterest {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func setSelectedRowSet(_ selected: Set<UID>, _ treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func removeExpandedRow(_ rowUID: UID, _ treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeForGDriveSelect() throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeFromConfig(treeID: String, isStartup: Bool) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeFromSPID(treeID: String, spid: SinglePathNodeIdentifier) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeFromUserPath(treeID: String, userPath: String) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createExistingDisplayTree(treeID: String, treeDisplayMode: TreeDisplayMode) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func requestDisplayTree(request: DisplayTreeRequest) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func dropDraggedNodes(srcTreeID: String, srcSNList: [SPIDNodePair], isInto: Bool, dstTreeID: String, dstSN: SPIDNodePair) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [SPIDNodePair], selectedChangeListRight: [SPIDNodePair]) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func enqueueRefreshSubtreeStatsTask(rootUID: UID, treeID: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getLastPendingOp(nodeUID: UID) throws -> UserOp? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func downloadFileFromGDrive(nodeUID: UID, requestorID: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func deleteSubtree(nodeUIDList: [UID]) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getFilterCriteria(treeID: String) throws -> FilterCriteria {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func updateFilterCriteria(treeID: String, filterCriteria: FilterCriteria) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }


}
