//
//  Backend.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//
import SwiftUI
import OutletCommon

protocol OutletBackend: HasLifecycle {
  var app: OutletAppProtocol { get }
  var nodeIdentifierFactory: NodeIdentifierFactory { get }

  func getConfig(_ configKey: String, defaultVal: String?) throws -> String
  func putConfig(_ configKey: String, _ configVal: String) throws
  func getConfigList(_ configKeyList: [String]) throws -> [String: String]
  func putConfigList(_ configDict: [String: String]) throws
  func getIntConfig(_ configKey: String, defaultVal: Int?) throws -> Int
  func getUInt32Config(_ configKey: String, defaultVal: UInt32?) throws -> UInt32
  func getBoolConfig(_ configKey: String, defaultVal: Bool?) throws -> Bool
  func getIcon(_ iconID: IconID) throws -> NSImage?
  
  //  func reportError(sender: String, msg: String, secondaryMsg: String?) throws
  func getNodeForUID(uid: UID, deviceUID: UID) throws -> TNode?
  func nextUID() throws -> UID
  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID?
  func getSNFor(nodeUID: UID, deviceUID: UID, fullPath: String) throws -> SPIDNodePair?
  func startSubtreeLoad(treeID: TreeID) throws
  func getOpExecutionPlayState() throws -> Bool
  func getDeviceList() throws -> [Device]
  func getDefaultLocalDeviceUID() throws -> UID
  func getTreeType(deviceUID: UID) throws -> TreeType
  func getChildList(_ parentSPID: SPID, treeID: TreeID?, isExpandingParent: Bool, maxResults: UInt32?) throws -> [SPIDNodePair]
  func getAncestorList(_ spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [SPIDNodePair]
  func getRowsOfInterest(treeID: TreeID) throws -> RowsOfInterest
  func setSelectedRowSet(_ selected: Set<GUID>, _ treeID: TreeID) throws
  func removeExpandedRow(_ rowUID: GUID, _ treeID: TreeID) throws
  func getContextMenu(treeID: TreeID, _ guidList: [GUID]) throws -> [MenuItemMeta]
  func executeTreeAction(_ treeAction: TreeAction) throws
  func executeTreeActionList(_ treeActionList: [TreeAction]) throws

  func createDisplayTreeForGDriveSelect(deviceUID: UID) throws -> DisplayTree?
  func createDisplayTreeFromConfig(treeID: TreeID, isStartup: Bool) throws -> DisplayTree?
  func createDisplayTreeFromSPID(treeID: TreeID, spid: SinglePathNodeIdentifier) throws -> DisplayTree?
  func createDisplayTreeFromUserPath(treeID: TreeID, userPath: String, deviceUID: UID) throws -> DisplayTree?
  func createExistingDisplayTree(treeID: TreeID, treeDisplayMode: TreeDisplayMode) throws -> DisplayTree?
  func requestDisplayTree(request: DisplayTreeRequest) throws -> DisplayTree?
  
  func dropDraggedNodes(srcTreeID: TreeID, srcGUIDList: [GUID], isInto: Bool, dstTreeID: TreeID, dstGUID: GUID, dragOperation: DragOperation, dirConflictPolicy: DirConflictPolicy, fileConflictPolicy: FileConflictPolicy)
    throws -> Bool
  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs
  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [GUID], selectedChangeListRight: [GUID]) throws
  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: TreeID) throws
  func getLastPendingOp(deviceUID: UID, nodeUID: UID) throws -> UserOp?
  func downloadFileFromGDrive(deviceUID: UID, nodeUID: UID, requestorID: String) throws
  func deleteSubtree(deviceUID: UID, nodeUIDList: [UID]) throws
  func getFilterCriteria(treeID: TreeID) throws -> FilterCriteria
  func updateFilterCriteria(treeID: TreeID, filterCriteria: FilterCriteria) throws
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

  func getUInt32Config(_ configKey: String) throws -> UInt32 {
    return try getUInt32Config(configKey, defaultVal: nil)
  }

  func getBoolConfig(_ configKey: String) throws -> Bool {
    return try getBoolConfig(configKey, defaultVal: nil)
  }

  func getChildList(_ parentSPID: SPID, treeID: TreeID?, isExpandingParent: Bool) throws -> [SPIDNodePair] {
    return try getChildList(parentSPID, treeID: treeID, isExpandingParent: isExpandingParent, maxResults: MAX_NUMBER_DISPLAYABLE_CHILD_NODES)
  }
}

/**
 CLASS MockBackend

 Should be used only for testing & previews
 */
class MockBackend: OutletBackend {
  let app: OutletAppProtocol
  let dipatcher: SignalDispatcher
  let nodeIdentifierFactory = NodeIdentifierFactory()

  init(_ d: SignalDispatcher? = nil, _ app: OutletAppProtocol) {
    self.dipatcher = d ?? SignalDispatcher()
    self.app = app
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

  func getConfigList(_ configKeyList: [String]) throws -> [String: String] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func putConfigList(_ configDict: [String: String]) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getIntConfig(_ configKey: String, defaultVal: Int?) throws -> Int {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getUInt32Config(_ configKey: String, defaultVal: UInt32?) throws -> UInt32 {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getBoolConfig(_ configKey: String, defaultVal: Bool?) throws -> Bool {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getIcon(_ iconID: IconID) throws -> NSImage? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getNodeForUID(uid: UID, deviceUID: UID) throws -> TNode? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func nextUID() throws -> UID {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getUIDForLocalPath(fullPath: String, uidSuggestion: UID?) throws -> UID? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getSNFor(nodeUID: UID, deviceUID: UID, fullPath: String) throws -> SPIDNodePair? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func startSubtreeLoad(treeID: TreeID) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getOpExecutionPlayState() throws -> Bool {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getDeviceList() throws -> [Device] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getDefaultLocalDeviceUID() throws -> UID {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getTreeType(deviceUID: UID) throws -> TreeType {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getChildList(_ parentSPID: SPID, treeID: TreeID?, isExpandingParent: Bool, maxResults: UInt32?) throws -> [SPIDNodePair] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getAncestorList(_ spid: SinglePathNodeIdentifier, stopAtPath: String?) throws -> [SPIDNodePair] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getRowsOfInterest(treeID: TreeID) throws -> RowsOfInterest {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func setSelectedRowSet(_ selected: Set<GUID>, _ treeID: TreeID) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func removeExpandedRow(_ rowUID: GUID, _ treeID: TreeID) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getContextMenu(treeID: TreeID, _ guidList: [GUID]) throws -> [MenuItemMeta] {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func executeTreeAction(_ treeAction: TreeAction) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func executeTreeActionList(_ treeActionList: [TreeAction]) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeForGDriveSelect(deviceUID: UID) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeFromConfig(treeID: TreeID, isStartup: Bool) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeFromSPID(treeID: TreeID, spid: SinglePathNodeIdentifier) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createDisplayTreeFromUserPath(treeID: TreeID, userPath: String, deviceUID: UID) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func createExistingDisplayTree(treeID: TreeID, treeDisplayMode: TreeDisplayMode) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func requestDisplayTree(request: DisplayTreeRequest) throws -> DisplayTree? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func dropDraggedNodes(srcTreeID: TreeID, srcGUIDList: [GUID], isInto: Bool, dstTreeID: TreeID, dstGUID: GUID, dragOperation: DragOperation, dirConflictPolicy: DirConflictPolicy, fileConflictPolicy: FileConflictPolicy)
      throws -> Bool {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func startDiffTrees(treeIDLeft: String, treeIDRight: String) throws -> DiffResultTreeIDs {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func generateMergeTree(treeIDLeft: String, treeIDRight: String, selectedChangeListLeft: [GUID], selectedChangeListRight: [GUID]) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func enqueueRefreshSubtreeTask(nodeIdentifier: NodeIdentifier, treeID: TreeID) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getLastPendingOp(deviceUID: UID, nodeUID: UID) throws -> UserOp? {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func downloadFileFromGDrive(deviceUID: UID, nodeUID: UID, requestorID: String) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func deleteSubtree(deviceUID: UID, nodeUIDList: [UID]) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func getFilterCriteria(treeID: TreeID) throws -> FilterCriteria {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }

  func updateFilterCriteria(treeID: TreeID, filterCriteria: FilterCriteria) throws {
    throw OutletError.invalidOperation("Cannot call MockBackend methods")
  }


}
