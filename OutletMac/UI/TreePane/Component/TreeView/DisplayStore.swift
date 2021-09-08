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

 Note: although topmost GUID is nil in NSOutlineView, DisplayStore uses its normal GUID.
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

  private var rootGUID: GUID! = nil

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

  // Sorting
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

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

      self.rootGUID = rootSN.spid.guid
      self.primaryDict[self.rootGUID] = rootSN // needed for determining implicitly checked checkboxes

      self.putChildSNList_Internal(rootGUID, topLevelSNList)
    }
  }

  func putChildList(_ parentGUID: GUID, _ childSNList: [SPIDNodePair]) {
    dq.sync {
      self.putChildSNList_Internal(parentGUID, childSNList)
    }
  }

  private func putChildSNList_Internal(_ parentGUID: GUID, _ childSNList: [SPIDNodePair]) {
    let parentChecked: Bool = self.checkedNodeSet.contains(parentGUID)

    for childSN in childSNList {
      let childGUID = childSN.spid.guid
      self.primaryDict[childGUID] = childSN
      self.childParentDict[childGUID] = parentGUID

      if parentChecked {
        // all children are implicitly checked:
        self.checkedNodeSet.insert(childSN.spid.guid)
      }
    }

    self.parentChildListDict[parentGUID] = self.sortDirContents(snList: childSNList).map { $0.spid.guid }

    NSLog("DEBUG [\(self.treeID)] DisplayStore: stored \(childSNList.count) children for parent: \(parentGUID)")
  }

  func putSN(_ childSN: SPIDNodePair, parentGUID: GUID) -> Bool {
    var wasPresent: Bool = false
    dq.sync {
      let childGUID = childSN.spid.guid
      if self.primaryDict[childGUID] != nil {
        wasPresent = true
      }
      self.primaryDict[childGUID] = childSN

      // Parent -> Child
      if var existingParentChildList = self.parentChildListDict[parentGUID] {
        // TODO: this may get slow for very large directories...
        for (index, existing) in existingParentChildList.enumerated() {
          if existing == childGUID {
            // found: replace existing
            existingParentChildList[index] = childGUID
            break
          }
        }
        self.parentChildListDict[parentGUID] = existingParentChildList
      } else {
        self.parentChildListDict[parentGUID] = [childGUID]
      }

      NSLog("DEBUG Children of parent \(parentGUID): \(self.parentChildListDict[parentGUID])")

      // Child -> Parent
      self.childParentDict[childGUID] = parentGUID
    }

    return wasPresent
  }

  // "Remove" operations
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func removeSN(_ guid: GUID) -> Bool {
    var removed: Bool = false
    dq.sync {
      removed = self.removeSN_NoLock(guid)
    }
    return removed
  }

  func removeSubtree(_ guid: GUID) {
    dq.sync {
      for guid in self.getSelfAndAllDescendants(guid).reversed() {
        _ = self.removeSN_NoLock(guid)
      }
    }
  }

  func removeDescendants(_ guid: GUID) {
    dq.sync {
      for guid in self.getDescendants(guid).reversed() {
        _ = self.removeSN_NoLock(guid)
      }
    }
  }

  private func removeSN_NoLock(_ guid: GUID) -> Bool {
    // delete its checkbox state, if any:
    self.checkedNodeSet.remove(guid)
    self.mixedNodeSet.remove(guid)

    // if we are deleting a non-empty directory, it likely indicates an error on the backend. Not really our concern.
    // Just log error and continue.
    if let childList = self.parentChildListDict.removeValue(forKey: guid) {
      if childList.count > 0 {
        NSLog("ERROR [\(self.treeID)] Should not be deleting node which has children! DeletedNode \(guid) had \(childList.count) children")
      }
    }

    // delete back pointer to parent, and get parent GUID:
    if let parentGUID = self.childParentDict.removeValue(forKey: guid) {
      // delete from parent's list of children:
      if !self.removeChildFromParentChildDict(child: guid, parent: parentGUID) {
        NSLog("ERROR [\(self.treeID)] DisplayStore.removeSN(): \(guid) not found in list of children for parent: \(parentGUID) (found: \(self.parentChildListDict[parentGUID] ?? []))")
      }
    } else {
      NSLog("ERROR [\(self.treeID)] DisplayStore.removeSN(): \(guid) not found in ChildParentDict!")
    }

    if self.primaryDict.removeValue(forKey: guid) == nil {
      NSLog("ERROR [\(self.treeID)] DisplayStore.removeSN(): Could not remove GUID from DisplayStore because it wasn't found: \(guid)")
    } else {
      if SUPER_DEBUG_ENABLED {
        NSLog("DEBUG [\(self.treeID)] GUID removed from DisplayStore: \(guid)")
      }
      return true
    }
    return false
  }

  private func removeChildFromParentChildDict(child: GUID, parent: GUID) -> Bool {
    if var childrenOfParentList = self.parentChildListDict[parent] {
      if let index = childrenOfParentList.firstIndex(of: child) {
        childrenOfParentList.remove(at: index)
        self.parentChildListDict[parent] = childrenOfParentList
        return true
      }
    }
    return false
  }

  // "Get" operations
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  private func getSN_NoLock(_ guid: GUID) -> SPIDNodePair? {
    return self.primaryDict[guid] ?? nil
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

  /**
   Generic lookup func. Given a list of GUIDs, return a list of their corresponding Nodes in the same order.
   */
  public func getNodeList(_ guidList: [GUID]) -> [Node] {
    var nodeList: [Node] = []
    dq.sync {
      for guid in guidList {
        if let sn = self.getSN_NoLock(guid) {
          nodeList.append(sn.node)
        } else {
          NSLog("[\(self.treeID)] WARN  Could not find node for GUID; ommitting: \(guid)")
        }
      }
    }
    return nodeList
  }

  private func getChildGUIDList_NoLock(_ parentGUID: GUID) -> [GUID] {
    return self.parentChildListDict[parentGUID] ?? []
  }

  func getChildCount(_ parentGUID: GUID) -> Int? {
    var count: Int? = 0
    dq.sync {
      count = self.parentChildListDict[parentGUID]?.count
    }
    return count
  }

  /**
   Returns the list of child GUIDs for a given parent GUID.
   */
  func getChildGUIDList(_ parentGUID: GUID) -> [GUID] {
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
  func getChildSNList(_ parentGUID: GUID) -> [SPIDNodePair] {
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
  func getChild(_ parentGUID: GUID, _ childIndex: Int, useParentIfIndexInvalid: Bool = false) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    dq.sync {
      if childIndex < 0 {
        if useParentIfIndexInvalid {
          // Return parent instead
          sn = self.getSN_NoLock(parentGUID)
        } else {
          NSLog("ERROR [\(self.treeID)] DisplayStore.getChild(): childIndex (\(childIndex)) is negative! (parentGUID=\(parentGUID)")
          sn = nil
        }
      } else {
        let childList = self.parentChildListDict[parentGUID] ?? []
        if childIndex >= childList.count {
          if useParentIfIndexInvalid {
            sn = self.getSN_NoLock(parentGUID)
          } else {
            NSLog("ERROR [\(self.treeID)] DisplayStore.getChild(): Could not find child of parent GUID \(parentGUID) & index \(childIndex)")
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
    NSLog("[\(treeID)] ERROR DisplayStore: Could not find parent of GUID \(childGUID) in childParentDict!")
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
      NSLog("DEBUG [\(treeID)] updateCheckboxState(): setting self and descendants of \(guid): checked => \(newIsCheckedValue)")
      for guid in self.getSelfAndAllDescendants(guid) {
        self.updateCheckedStateTracking_NoLock(guid, isChecked: newIsCheckedValue, isMixed: false)
      }

      /*
       2. Siblings

       Housekeeping. Need to update all the siblings (children of parent) because their checked state may not be tracked.
       We can assume that if a parent is not mixed (i.e. is either checked or unchecked), the state of its children are implied.
       But if the parent is mixed, we must track the state of ALL of its children.
       */
      NSLog("DEBUG [\(treeID)] updateCheckboxState(): updating siblings of \(guid)")
      let parentSN = self.getParentSN_NoLock(guid)!
      let parentGUID = parentSN.spid.guid

      if parentGUID != self.rootGUID {
        for siblingGUID in self.getChildGUIDList_NoLock(parentGUID) {
          let state = self.getCheckboxState_NoLock(siblingGUID)
          NSLog("DEBUG [\(treeID)] updateCheckboxState(): Sibling \(siblingGUID) == \(DisplayStore.CHECKBOX_STATE_NAMES[state.rawValue])")
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
    NSLog("DEBUG [\(treeID)] UpdateCheckedStateTracking: Setting node \(guid): checked=\(isChecked) mixed=\(isMixed)")

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

  public func isDir(_ guid: GUID) -> Bool {
    return self.getSN(guid)?.node.isDir ?? false
  }

  public func updateDirStats(_ byGUID: Dictionary<GUID, DirectoryStats>, _ byUID: Dictionary<UID, DirectoryStats>) {
    dq.sync {
      NSLog("DEBUG [\(self.treeID)] Updating dir stats with counts: byGUID=\(byGUID.count), byUID=\(byUID.count)")
      for (guid, sn) in self.primaryDict {
        if !sn.node.isEphemeral && sn.node.isDir {
          if byGUID.count > 0 {
            if let dirStats = byGUID[guid] {
              sn.node.setDirStats(dirStats)
              self.primaryDict[guid] = sn
            }
          } else if byUID.count > 0 {
            if let dirStats = byUID[sn.node.uid] {
              sn.node.setDirStats(dirStats)
              self.primaryDict[guid] = sn
            }
          }
        }
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

  /**
   Applies the given applyFunc to the given item's descendants in breadth-first order.
   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  private func getDescendants(_ guid: GUID) -> LinkedList<GUID> {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    return bfsList(guid, includeTopmostGUID: false)
  }

  /**
   Returns a list of the GUID and its descendants in breadth-first order.
   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  private func getSelfAndAllDescendants(_ guid: GUID) -> LinkedList<GUID> {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    return bfsList(guid, includeTopmostGUID: true)
  }

  /**
   Returns a list of GUIDs in the given subtree in breadth-first order.
   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  private func bfsList(_ topmostGUID: GUID, includeTopmostGUID: Bool) -> LinkedList<GUID> {
    var bfsList = LinkedList<GUID>()

    guard let sn = self.getSN_NoLock(topmostGUID) else {
      return bfsList
    }

    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG [\(treeID)] bfsList(): topmost_spid=\(sn.spid)")
    }

    var searchQueue = LinkedList<GUID>()
    if includeTopmostGUID {
      bfsList.append(topmostGUID)
    }
    for childGUID in self.getChildGUIDList_NoLock(topmostGUID) {
      searchQueue.append(childGUID)
    }


    while !searchQueue.isEmpty {
      let guid = searchQueue.popFirst()!
      bfsList.append(guid)

      for childGUID in self.getChildGUIDList_NoLock(guid) {
        searchQueue.append(childGUID)
      }
    }

    return bfsList
  }
}
