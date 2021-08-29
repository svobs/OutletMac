//
//  DisplayStore.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/21.
//

import AppKit
import LinkedList

typealias ApplyToSNFunc = (_ sn: SPIDNodePair) -> Void

/**
 I suppose this class a repository for "ModelView" objects in the MVVC design pattern.
 */
class DisplayStore {
  private static let CHECKBOX_STATE_NAMES: [String] = ["off", "on", "mixed"]
  weak var con: TreePanelControllable! = nil  // Need to set this in parent controller's start() method

  private let dq = DispatchQueue(label: "DisplayStore SerialQueue") // custom dispatch queues are serial by default

  private var treeID: TreeID {
    get {
      return self.con.treeID
    }
  }

  private var colSortOrder: ColSortOrder = .NAME
  private var sortAscending: Bool = true

  // Need to keep each list in here sorted according to the current UI setting:
  private var parentChildListDict: [GUID: [GUID]] = [:]
  private var primaryDict: [GUID: SPIDNodePair] = [:]
  // Back pointer to each parent (for speed)
  private var childParentDict: [GUID: GUID] = [:]

  /*
   Track the checkbox states here. For increased speed and to accommodate lazy loading strategies,
   we employ the following heuristic:
    - When a user checks a row, it goes in 'checkedNodeSet' below.
    - When it is placed in checkedNodeSet, it is implied that all its descendants are also checked.
    - Similarly, when an item is unchecked by the user, all of its descendants are implied to be unchecked.
    - HOWEVER, un-checking an item will not delete any descendants that may be in the 'checkedNodeSet' list.
      Anything in the 'checkedNodeSet' and 'mixedNodeSet' sets is only relevant if its parent is 'mixed',
      thus, having a parent which is either checked or unchecked overrides any presence in either of these two lists.
    - At the same time as an item is checked, the checked & mixed state of its all ancestors must be recorded.
    - The 'mixedNodeSet' set is needed for display purposes.

   Not used if the TreeView does not contain checkboxes.
  */
  private var checkedNodeSet = Set<GUID>()
  private var mixedNodeSet = Set<GUID>()

  func isLoaded() -> Bool {
    var isLoaded = false
    let topmostGUID = self.con.tree.rootSPID.guid
    dq.sync {
      for sn in self.primaryDict.values {
        if !sn.node.isEphemeral && sn.spid.guid != topmostGUID {
          NSLog("DEBUG isLoaded(): node is not ephemeral: \(sn.spid)")
          isLoaded = true
          break
        }
      }
    }
    return isLoaded
  }

  private func upsertParentChildRelationship_NoLock(parentGUID: GUID?, _ childSN: SPIDNodePair) {
    let childGUID: GUID = childSN.spid.guid
    var realParentGUID: GUID = (parentGUID == nil) ? TOPMOST_GUID : parentGUID!
    if realParentGUID == self.con.tree.rootSPID.guid {
      realParentGUID = TOPMOST_GUID
    }

    // Parent -> Child
    // note: top-level's parent is 'nil' in OutlineView, but is TOPMOST_GUID in DisplayStore
    if self.parentChildListDict[realParentGUID] == nil {
      self.parentChildListDict[realParentGUID] = []
    }
    // TODO: this may get slow for very large directories...
    for (index, existing) in self.parentChildListDict[realParentGUID]!.enumerated() {
      if existing == childGUID {
        // found: replace existing
        self.parentChildListDict[realParentGUID]![index] = childGUID
        return
      }
    }
    self.parentChildListDict[realParentGUID]!.append(childGUID)

    // Child -> Parent
    self.childParentDict[childGUID] = realParentGUID
  }

  func getColSortOrder() -> ColSortOrder {
    return self.colSortOrder
  }

  func updateColSortOrder(_ sortKey: String, _ isAscending: Bool) {
    let colSortOrder: ColSortOrder

    switch sortKey {
    case NAME_COL_KEY:
      colSortOrder = .NAME
      break
    case SIZE_COL_KEY:
      colSortOrder = .SIZE
      break
    case MODIFY_TS_COL_KEY:
      colSortOrder = .MODIFY_TS
      break
    case META_CHANGE_TS_COL_KEY:
      colSortOrder = .CHANGE_TS
      break
    default:
      fatalError("Unrecognized sort key: \(sortKey)")
    }

    dq.sync {
      self.colSortOrder = colSortOrder
      self.sortAscending = isAscending
      for (parentGUID, childList) in self.parentChildListDict {
        self.parentChildListDict[parentGUID] = self.sortDirContents(childList)
      }
    }
  }

  private func toSNList(guidList: [GUID]) throws -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []

    for guid in guidList {
      let sn = primaryDict[guid]
      if sn == nil {
        throw OutletError.invalidState("toSNList(): failed to find GUID in primaryDict: \(guid)")
      }
      snList.append(sn!)
    }

    return snList
  }

  private func sortDirContents(_ childList: [GUID]) -> [GUID] {
    // convert from [GUID] to [SPIDNodePair]. If error occurs, fail
    let snList: [SPIDNodePair]
    do {
      snList = try toSNList(guidList: childList)
    } catch {
      NSLog("[\(self.treeID)] ERROR sortDirContents() failed: \(error)")
      return childList
    }

    let snSortedList: [SPIDNodePair] = sortDirContents(snList: snList)
    return snSortedList.map { $0.spid.guid }  // convert back to [GUID]
  }

  private func sortDirContents(snList: [SPIDNodePair]) -> [SPIDNodePair] {
    let snSortedList: [SPIDNodePair]
    switch self.colSortOrder {
    case .NAME:
      let desiredOrder: ComparisonResult = (self.sortAscending ? .orderedAscending : .orderedDescending)
      snSortedList = snList.sorted { $0.node.name.localizedCaseInsensitiveCompare($1.node.name) == desiredOrder }
    case .SIZE:
      if self.sortAscending {
        // put nodes with missing size at the end
        snSortedList = snList.sorted { ($0.node.sizeBytes ?? UInt64.max) < ($1.node.sizeBytes ?? UInt64.max) }
      } else {
        snSortedList = snList.sorted { ($0.node.sizeBytes ?? UInt64.max) > ($1.node.sizeBytes ?? UInt64.max) }
      }
    case .MODIFY_TS:
      if self.sortAscending {
        // put nodes with missing TS at the end
        snSortedList = snList.sorted { ($0.node.modifyTS ?? UInt64.max) < ($1.node.modifyTS ?? UInt64.max) }
      } else {
        snSortedList = snList.sorted { ($0.node.modifyTS ?? UInt64.max) > ($1.node.modifyTS ?? UInt64.max) }
      }
    case .CHANGE_TS:
      if self.sortAscending {
        // put nodes with missing TS at the end
        snSortedList = snList.sorted { ($0.node.changeTS ?? UInt64.max) < ($1.node.changeTS ?? UInt64.max) }
      } else {
        snSortedList = snList.sorted { ($0.node.changeTS ?? UInt64.max) > ($1.node.changeTS ?? UInt64.max) }
      }
    }

    return snSortedList
  }

  // "Put" operations
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Clears all data structures. Populates the data structures with the given SNs, then returns them.
  */
  func putRootChildList(_ rootSN: SPIDNodePair, _ topLevelSNList: [SPIDNodePair]) -> Void {
    dq.sync {
      self.primaryDict.removeAll()
      self.childParentDict.removeAll()
      self.parentChildListDict.removeAll()
      self.checkedNodeSet.removeAll()
      self.mixedNodeSet.removeAll()

      self.primaryDict[TOPMOST_GUID] = rootSN // needed for determining implicitly checked checkboxes

      let sortedList = self.sortDirContents(snList: topLevelSNList)
      self.parentChildListDict[TOPMOST_GUID] = sortedList.map { $0.spid.guid }
      for childSN in sortedList {
        let childGUID = childSN.spid.guid
        self.primaryDict[childGUID] = childSN
        self.childParentDict[childGUID] = TOPMOST_GUID
      }
    }
  }

  func putChildList(_ parentSN: SPIDNodePair?, _ childSNList: [SPIDNodePair]) {
    dq.sync {
      // note: top-level's parent is 'nil' in OutlineView, but is TOPMOST_GUID in DisplayStore
      let parentGUID = parentSN == nil ? TOPMOST_GUID : parentSN!.spid.guid
      let parentChecked: Bool = parentSN != nil && self.checkedNodeSet.contains(parentSN!.spid.guid)

      for childSN in childSNList {
        let childGUID = childSN.spid.guid
        self.primaryDict[childGUID] = childSN
        self.childParentDict[childGUID] = parentGUID

        if parentChecked {
          // all children are implicitly checked:
          self.checkedNodeSet.insert(childSN.spid.guid)
        }
      }
      let sortedGUIDList = self.sortDirContents(snList: childSNList).map { $0.spid.guid }
      self.parentChildListDict[parentGUID] = sortedGUIDList

      NSLog("DEBUG [\(self.treeID)] DisplayStore: stored \(childSNList.count) children for parent: \(parentGUID)")
    }
  }

  func upsertSN(_ parentGUID: GUID?, _ childSN: SPIDNodePair) -> Bool {
    var wasPresent: Bool = false
    dq.sync {
      let childGUID = childSN.spid.guid
      if self.primaryDict[childGUID] != nil {
        wasPresent = true
      }
      self.primaryDict[childGUID] = childSN
      self.upsertParentChildRelationship_NoLock(parentGUID: parentGUID, childSN)
    }

    return wasPresent
  }

  // "Get" operations
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func getSN_NoLock(_ guid: GUID?) -> SPIDNodePair? {
    return self.primaryDict[guid ?? TOPMOST_GUID] ?? nil
  }

  /**
   Lookup func. Given a GUID, return its corresponding SPIDNodePair.
   */
  func getSN(_ guid: GUID) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    dq.sync {
      sn = self.getSN_NoLock(guid)
    }
    return sn
  }

  /**
   Generic lookup func. Given a list of GUIDs, return a list of their corresponding SPIDNodePairs in the same order.
   */
  public func getSNList(_ guidList: [GUID]) -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    dq.sync {
      for guid in guidList {
        if let sn = self.getSN_NoLock(guid) {
          snList.append(sn)
        } else {
          NSLog("[\(self.treeID)] WARN  Could not find SN for GUID; ommitting: \(guid)")
        }
      }
    }
    return snList
  }

  private func getChildGUIDList_NoLock(_ parentGUID: GUID?) -> [GUID] {
    return self.parentChildListDict[parentGUID ?? TOPMOST_GUID] ?? []
  }

  func getChildCount(_ parentGUID: GUID?) -> Int? {
    var count: Int? = 0
    dq.sync {
      count = self.parentChildListDict[parentGUID ?? TOPMOST_GUID]?.count
    }
    return count
  }

  /**
   Returns the list of child GUIDs for a given parent GUID.
   */
  func getChildGUIDList(_ parentGUID: GUID?) -> [GUID] {
    var guidList: [GUID] = []
    dq.sync {
      guidList = self.getChildGUIDList_NoLock(parentGUID)
    }
    return guidList
  }

  /**
   Returns the list of children for a given parent GUID as SPIDNodePairs. This is similar to getChildGUIDList, but is a slightly heavier operation,
   so getChildGUIDList should be used if possible.
   */
  func getChildSNList(_ parentGUID: GUID?) -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    dq.sync {
      let guidList = self.getChildGUIDList_NoLock(parentGUID)
      do {
        snList = try self.toSNList(guidList: guidList)
      } catch {
        NSLog("ERROR: getChildSNList(): toSNList() failed (no results will be returned!): \(error)")
      }
    }
    return snList
  }


  /**
   Called by NSOutlineView: returns a SPIDNodePair for the requested parent's key (GUID) and zero-based index.
   Sort-order dependent!
   */
  func getChild(_ parentGUID: GUID?, _ childIndex: Int, useParentIfIndexInvalid: Bool = false) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    dq.sync {
      if childIndex < 0 {
        if useParentIfIndexInvalid {
          // Return parent instead
          sn = self.getSN_NoLock(parentGUID)
        } else {
          NSLog("ERROR [\(self.treeID)] getChild(): childIndex (\(childIndex)) is negative! (parentGUID=\(parentGUID ?? TOPMOST_GUID)")
          sn = nil
        }
      } else {
        let childList = self.parentChildListDict[parentGUID ?? TOPMOST_GUID] ?? []
        if childIndex >= childList.count {
          if useParentIfIndexInvalid {
            sn = self.getSN_NoLock(parentGUID)
          } else {
            NSLog("ERROR [\(self.treeID)] getChild(): Could not find child of parent GUID \(parentGUID ?? TOPMOST_GUID) & index \(childIndex)")
            sn = nil
          }
        } else {
          sn = getSN_NoLock(childList[childIndex])
        }
      }
    }
    return sn
  }

  func getParentGUID(_ childGUID: GUID) -> GUID? {
    var parentGUID: GUID? = nil
    dq.sync {
      parentGUID = self.childParentDict[childGUID]
    }
    return parentGUID
  }

  private func getParentSN_NoLock(_ childGUID: GUID) -> SPIDNodePair? {
    if let parentGUID = self.childParentDict[childGUID] {
      return self.primaryDict[parentGUID]
    }
    NSLog("[\(treeID)] ERROR Could not find parent of GUID \(childGUID) in childParentDict!")
    return nil
  }

  func getParentSN(_ childGUID: GUID) -> SPIDNodePair? {
    var parentSN: SPIDNodePair? = nil
    dq.sync {
      parentSN = self.getParentSN_NoLock(childGUID)
    }
    return parentSN
  }

  // Checkbox State
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func getCheckedAndMixedRows() -> (Set<GUID>, Set<GUID>) {
    return (self.checkedNodeSet, self.mixedNodeSet)
  }

  private func isCheckboxChecked_NoLock(_ guid: GUID) -> Bool {
    guard let sn = getSN_NoLock(guid) else {
      NSLog("[\(treeID)] ERROR isCheckboxChecked_NoLock(): Could not find GUID \(guid) in primaryDict! Returning false")
      return false
    }

    if sn.node.isEphemeral {
      return false
    }

    if self.checkedNodeSet.contains(sn.spid.guid) {
      return true
    }

    return false
  }

  func updateCheckboxStateForSameLevelAndBelow(_ guid: GUID, _ newIsCheckedValue: Bool, _ treeID: TreeID) {
    dq.sync {

      /*
       1. Self and children
       Need to update all the children of the node to match its checked state.
       This will not update it in the UI, however.
       */
      NSLog("DEBUG [\(treeID)] setNodeCheckedState(): setting self and descendants of \(guid): checked => \(newIsCheckedValue)")
      let applyFunc: ApplyToSNFunc = { sn in self.updateCheckedStateTracking_NoLock(guid, isChecked: newIsCheckedValue, isMixed: false) }
      self.doForSelfAndAllDescendants(guid, applyFunc)

      /*
       2. Siblings

       Housekeeping. Need to update all the siblings (children of parent) because their checked state may not be tracked.
       We can assume that if a parent is not mixed (i.e. is either checked or unchecked), the state of its children are implied.
       But if the parent is mixed, we must track the state of ALL of its children.
       */
      NSLog("DEBUG [\(treeID)] setNodeCheckedState(): updating siblings of \(guid)")
      let parentSN = self.getParentSN_NoLock(guid)!
      let parentGUID = parentSN.spid.guid

      if parentGUID != TOPMOST_GUID {
        for siblingGUID in self.getChildGUIDList_NoLock(parentGUID) {
          let state = self.getCheckboxState_NoLock(siblingGUID)
          NSLog("DEBUG [\(treeID)] Sibling \(siblingGUID) == \(DisplayStore.CHECKBOX_STATE_NAMES[state.rawValue])")
          self.updateCheckedStateTracking_NoLock(siblingGUID, isChecked: state == .on, isMixed: state == .mixed)
        }
      }
    }
  }

  private func getCheckboxState_NoLock(_ guid: GUID) -> NSControl.StateValue {
    if self.isCheckboxChecked_NoLock(guid) {
      return .on
    } else if self.mixedNodeSet.contains(guid) {
      return .mixed
    } else {
      return .off
    }
  }

  // includes implicit values based on parent
  func getCheckboxState(_ guid: GUID) -> NSControl.StateValue {
    var state: NSControl.StateValue = .off
    dq.sync {
      state = self.getCheckboxState_NoLock(guid)
    }
    return state
  }

  func isCheckboxChecked(_ guid: GUID) -> Bool {
    var isChecked: Bool = false
    dq.sync {
      isChecked = self.isCheckboxChecked_NoLock(guid)
    }
    return isChecked
  }

  func isCheckboxMixed(_ guid: GUID) -> Bool {
    var isMixed: Bool = false
    dq.sync {
      isMixed = self.mixedNodeSet.contains(guid)
    }
    return isMixed
  }

  private func updateCheckedStateTracking_NoLock(_ guid: GUID, isChecked: Bool, isMixed: Bool) {
    NSLog("DEBUG [\(treeID)] Setting node \(guid): checked=\(isChecked) mixed=\(isMixed)")

    if isChecked {
      self.checkedNodeSet.insert(guid)
    } else {
      self.checkedNodeSet.remove(guid)
    }

    if isMixed {
      self.mixedNodeSet.insert(guid)
    } else {
      self.mixedNodeSet.remove(guid)
    }

  }

  func updateCheckedStateTracking(_ guid: GUID, isChecked: Bool, isMixed: Bool) {
    dq.sync {
      self.updateCheckedStateTracking_NoLock(guid, isChecked: isChecked, isMixed: isMixed)
    }
  }

  // Other
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func removeSN_NoLock(_ guid: GUID) -> Bool {
    self.checkedNodeSet.remove(guid)
    self.mixedNodeSet.remove(guid)
    self.parentChildListDict.removeValue(forKey: guid)

    if self.primaryDict.removeValue(forKey: guid) == nil {
      NSLog("ERROR [\(self.treeID)] Could not remove GUID from DisplayStore because it wasn't found: \(guid)")
    } else {
      if SUPER_DEBUG_ENABLED {
        NSLog("DEBUG [\(self.treeID)] GUID removed from DisplayStore: \(guid)")
      }
      return true
    }
    return false
  }

  func removeSN(_ guid: GUID) -> Bool {
    var removed: Bool = false
    dq.sync {
      removed = self.removeSN_NoLock(guid)
    }
    return removed
  }

  public func removeSubtree(_ guid: GUID) {
    let applyFunc: ApplyToSNFunc = { sn in
      _ = self.removeSN_NoLock(sn.spid.guid)
    }

    dq.sync {
      self.doForDescendants(guid, applyFunc)
    }
  }

  public func isDir(_ guid: GUID) -> Bool {
    return self.getSN(guid)?.node.isDir ?? false
  }

  public func updateDirStats(_ byGUID: Dictionary<GUID, DirectoryStats>, _ byUID: Dictionary<UID, DirectoryStats>) {
    dq.sync {
      for (guid, sn) in self.primaryDict {
        if byGUID.count > 0 {
          if let dirStats = byGUID[guid] {
            if sn.node.isDir {
              sn.node.setDirStats(dirStats)
              self.primaryDict[guid] = sn
            } else {
              NSLog("ERROR [\(treeID)] Cannot update DirStats: Node is not a dir: \(sn.spid) (matched guid=\(guid))")
            }
          }
        } else if byUID.count > 0 {
          if let dirStats = byUID[sn.node.uid] {
            if sn.node.isDir {
              sn.node.setDirStats(dirStats)
              self.primaryDict[guid] = sn
            } else {
              NSLog("ERROR [\(treeID)] Cannot update DirStats: Node is not a dir: \(sn.spid) (matched node_uid=\(sn.node.uid))")
            }
          }
        }
      }
    }
  }

  /**
   Applies the given applyFunc to the given item's descendants in breadth-first order.

   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  private func doForDescendants(_ guid: GUID, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    applyBreadthFirst(guid, includeTopmostGUID: false, applyFunc)
  }

  /**
   Applies the given applyFunc to the given item and its descendants in breadth-first order.

   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  private func doForSelfAndAllDescendants(_ guid: GUID, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    applyBreadthFirst(guid, includeTopmostGUID: true, applyFunc)
  }

  /**
   Applies the given applyFunc to each item in the given searchQueue and its descendants in the queue in breadth-first order.
   The queue is assumed to contain an initial set of SPIDNodePairs, and will be depleted at the end.

   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  private func applyBreadthFirst(_ topmostGUID: GUID, includeTopmostGUID: Bool, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.

    guard let sn = self.getSN_NoLock(topmostGUID) else {
      return
    }

    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG [\(treeID)] doForSelfAndAllDescendants(): self=\(sn.spid)")
    }

    var searchQueue = LinkedList<GUID>()
    if includeTopmostGUID {
      searchQueue.append(topmostGUID)
    } else {
      for childGUID in self.getChildGUIDList_NoLock(topmostGUID) {
        searchQueue.append(childGUID)
      }
    }


    while !searchQueue.isEmpty {
      let guid = searchQueue.popFirst()!

      for childGUID in self.getChildGUIDList_NoLock(guid) {
        searchQueue.append(childGUID)
      }

      // Apply this AFTER adding its children
      if let sn = getSN_NoLock(guid) {
        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG [\(treeID)] applyBreadthFirst(): applying func for: \(sn.spid)")
        }
        applyFunc(sn)
      } else {
        // should never happen but let's log if it does
        NSLog("ERROR [\(treeID)] applyBreadthFirst(): failed to find SN for GUID, skipping: \(guid)")
      }
    }
  }
}
