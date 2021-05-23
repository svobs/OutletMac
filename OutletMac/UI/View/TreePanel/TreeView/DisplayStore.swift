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
  private var con: TreePanelControllable

  private var treeID: TreeID {
    get {
      return self.con.treeID
    }
  }

  private var parentChildListDict: [GUID: [SPIDNodePair]] = [:]
  private var primaryDict: [GUID: SPIDNodePair] = [:]
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

  init(_ controllable: TreePanelControllable) {
    self.con = controllable
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
      if existing.spid.guid == childGUID {
        // found: replace existing
        self.parentChildListDict[realParentGUID]![index] = childSN
        return
      }
    }
    self.parentChildListDict[realParentGUID]!.append(childSN)

    // Child -> Parent
    self.childParentDict[childGUID] = realParentGUID
  }

  // "Put" operations
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Clears all data structures. Populates the data structures with the given SNs, then returns them.
  */
  func putRootChildList(_ rootSN: SPIDNodePair, _ topLevelSNList: [SPIDNodePair]) -> Void {
    con.app.execSync {
      self.primaryDict.removeAll()
      self.childParentDict.removeAll()
      self.parentChildListDict.removeAll()
      self.checkedNodeSet.removeAll()
      self.mixedNodeSet.removeAll()

      self.primaryDict[TOPMOST_GUID] = rootSN // needed for determining implicitly checked checkboxes
      self.parentChildListDict[TOPMOST_GUID] = topLevelSNList
      for childSN in topLevelSNList {
        let childGUID = childSN.spid.guid
        self.primaryDict[childGUID] = childSN
        self.childParentDict[childGUID] = TOPMOST_GUID
      }
    }
  }

  func putChildList(_ parentSN: SPIDNodePair?, _ childSNList: [SPIDNodePair]) {
    con.app.execSync {
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
      self.parentChildListDict[parentGUID] = childSNList
    }
  }

  func upsertSN(_ parentGUID: GUID?, _ childSN: SPIDNodePair) -> Bool {
    var wasPresent: Bool = false
    con.app.execSync {
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

  func getSN(_ guid: GUID) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    con.app.execSync {
      sn = self.getSN_NoLock(guid)
    }
    return sn
  }

  func getSNList(_ guidList: [GUID]) -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    con.app.execSync {
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

  func getChildListForRoot() -> [SPIDNodePair] {
    return self.getChildList(TOPMOST_GUID)
  }

  private func getChildList_NoLock(_ parentGUID: GUID?) -> [SPIDNodePair] {
    return self.parentChildListDict[parentGUID ?? TOPMOST_GUID] ?? []
  }

  func getChildCount(_ parentGUID: GUID?) -> Int? {
    var count: Int? = 0
    con.app.execSync {
      count = self.parentChildListDict[parentGUID ?? TOPMOST_GUID]?.count
    }
    return count
  }

  func getChildList(_ parentGUID: GUID?) -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    con.app.execSync {
      snList = self.getChildList_NoLock(parentGUID)
    }
    return snList
  }

  func getChild(_ parentGUID: GUID?, _ childIndex: Int, useParentIfIndexInvalid: Bool = false) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    con.app.execSync {
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
          sn = childList[childIndex]
        }
      }
    }
    return sn
  }

  func getParentGUID(_ childGUID: GUID) -> GUID? {
    var parentGUID: GUID? = nil
    con.app.execSync {
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
    con.app.execSync {
      parentSN = self.getParentSN_NoLock(childGUID)
    }
    return parentSN
  }

  // Checkbox State
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func getCheckedAndMixedRows() -> (Set<GUID>, Set<GUID>) {
    return (self.checkedNodeSet, self.mixedNodeSet)
  }

  private func isCheckboxChecked_NoLock(_ sn: SPIDNodePair) -> Bool {
    if let node = sn.node, node.isEphemeral {
      return false
    }

    if self.checkedNodeSet.contains(sn.spid.guid) {
      return true
    }

    return false
  }

  func updateCheckboxStateForSameLevelAndBelow(_ guid: GUID, _ newIsCheckedValue: Bool, _ treeID: TreeID) {
    con.app.execSync {

      /*
       1. Self and children
       Need to update all the children of the node to match its checked state.
       This will not update it in the UI, however.
       */
      NSLog("DEBUG [\(treeID)] setNodeCheckedState(): setting self and descendants of \(guid): checked => \(newIsCheckedValue)")
      let applyFunc: ApplyToSNFunc = { sn in self.updateCheckedStateTracking_NoLock(sn, isChecked: newIsCheckedValue, isMixed: false) }
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
        for siblingSN in self.getChildList_NoLock(parentGUID) {
          let state = self.getCheckboxState_NoLock(siblingSN)
          NSLog("DEBUG [\(treeID)] Sibling \(siblingSN.spid.guid) == \(DisplayStore.CHECKBOX_STATE_NAMES[state.rawValue])")
          self.updateCheckedStateTracking_NoLock(siblingSN, isChecked: state == .on, isMixed: state == .mixed)
        }
      }
    }
  }

  private func getCheckboxState_NoLock(_ sn: SPIDNodePair) -> NSControl.StateValue {
    if self.isCheckboxChecked_NoLock(sn) {
      return .on
    } else if self.mixedNodeSet.contains(sn.spid.guid) {
      return .mixed
    } else {
      return .off
    }
  }

  // includes implicit values based on parent
  func getCheckboxState(_ sn: SPIDNodePair) -> NSControl.StateValue {
    var state: NSControl.StateValue = .off
    con.app.execSync {
      state = self.getCheckboxState_NoLock(sn)
    }
    return state
  }

  func isCheckboxChecked(_ sn: SPIDNodePair) -> Bool {
    var isChecked: Bool = false
    con.app.execSync {
      isChecked = self.isCheckboxChecked_NoLock(sn)
    }
    return isChecked
  }

  func isCheckboxMixed(_ sn: SPIDNodePair) -> Bool {
    var isMixed: Bool = false
    con.app.execSync {
      isMixed = self.mixedNodeSet.contains(sn.spid.guid)
    }
    return isMixed
  }

  private func updateCheckedStateTracking_NoLock(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    let guid: GUID = sn.spid.guid

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

  func updateCheckedStateTracking(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    con.app.execSync {
      self.updateCheckedStateTracking_NoLock(sn, isChecked: isChecked, isMixed: isMixed)
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
      NSLog("DEBUG [\(self.treeID)] GUID removed from DisplayStore: \(guid)")
      return true
    }
    return false
  }

  func removeSN(_ guid: GUID) -> Bool {
    var removed: Bool = false
    con.app.execSync {
      removed = self.removeSN_NoLock(guid)
    }
    return removed
  }

  func removeSubtree(_ guid: GUID) {
    let applyFunc: ApplyToSNFunc = { sn in
      _ = self.removeSN_NoLock(sn.spid.guid)
    }

    con.app.execSync {
      self.doForDescendants(guid, applyFunc)
    }
  }

  func isDir(_ guid: GUID) -> Bool {
    return self.getSN(guid)?.node!.isDir ?? false
  }

  /**
   Applies the given applyFunc to the given item's descendants in breadth-first order.

   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  func doForDescendants(_ guid: GUID, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    var searchQueue = LinkedList<SPIDNodePair>()

    if let sn = self.getSN_NoLock(guid) {

      NSLog("DEBUG [\(treeID)] doForSelfAndAllDescendants(): self=\(sn.spid)")
      for childSN in self.getChildList_NoLock(sn.spid.guid) {
        searchQueue.append(childSN)
      }

      applyBreadthFirst(&searchQueue, applyFunc)
    }
  }

  /**
   Applies the given applyFunc to the given item and its descendants in breadth-first order.

   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  func doForSelfAndAllDescendants(_ guid: GUID, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    var searchQueue = LinkedList<SPIDNodePair>()

    if let sn = self.getSN_NoLock(guid) {
      NSLog("DEBUG [\(treeID)] doForSelfAndAllDescendants(): self=\(sn.spid)")
      searchQueue.append(sn)

      applyBreadthFirst(&searchQueue, applyFunc)
    }
  }

  /**
   Applies the given applyFunc to each item in the given searchQueue and its descendants in the queue in breadth-first order.
   The queue is assumed to contain an initial set of SPIDNodePairs, and will be depleted at the end.

   Note: this should be executed inside a dispatch queue. It is not thread-safe on its own
   */
  private func applyBreadthFirst(_ searchQueue: inout LinkedList<SPIDNodePair>, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    while !searchQueue.isEmpty {
      let sn = searchQueue.popFirst()!

      for childSN in self.getChildList_NoLock(sn.spid.guid) {
        searchQueue.append(childSN)
      }

      // Apply this AFTER adding its children
      NSLog("DEBUG [\(treeID)] doForSelfAndAllDescendants(): applying func for: \(sn.spid)")
      applyFunc(sn)
    }
  }
}
