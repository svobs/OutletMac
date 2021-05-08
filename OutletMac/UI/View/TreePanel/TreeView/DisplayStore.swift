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

   These are sets of node UIDs, not GUIDs, because checking a node in the GUI must check all instances of that node,
   not just the instance denoted by the GUID.

   Not used if the TreeView does not contain checkboxes.
  */
  private var checkedNodeSet = Set<UID>()
  private var mixedNodeSet = Set<UID>()

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
      let parentChecked: Bool = parentSN != nil && self.checkedNodeSet.contains(parentSN!.spid.nodeUID)

      for childSN in childSNList {
        let childGUID = childSN.spid.guid
        self.primaryDict[childGUID] = childSN
        self.childParentDict[childGUID] = parentGUID

        if parentChecked {
          // all children are implicitly checked:
          self.checkedNodeSet.insert(childSN.spid.nodeUID)
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

  private func getSN_NoLock(_ guid: GUID) -> SPIDNodePair? {
    return self.primaryDict[guid] ?? nil
  }

  func getSN(_ guid: GUID) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    con.app.execSync {
      sn = self.getSN_NoLock(guid)
    }
    return sn
  }

  func getChildListForRoot() -> [SPIDNodePair] {
    return self.getChildList(TOPMOST_GUID)
  }

  private func getChildList_NoLock(_ parentGUID: GUID?) -> [SPIDNodePair] {
    return self.parentChildListDict[parentGUID ?? TOPMOST_GUID] ?? []
  }

  func getChildList(_ parentGUID: GUID?) -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    con.app.execSync {
      snList = self.getChildList_NoLock(parentGUID)
    }
    return snList
  }

  func getChild(_ parentGUID: GUID?, _ childIndex: Int) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    con.app.execSync {
      let childList = self.parentChildListDict[parentGUID ?? TOPMOST_GUID] ?? []
      if childIndex >= childList.count {
        NSLog("ERROR Could not find child of parent GUID \(parentGUID ?? TOPMOST_GUID) & index \(childIndex)")
        sn = nil
      } else {
        sn = childList[childIndex]
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
    NSLog("ERROR Could not find parent of GUID \(childGUID) in childParentDict!")
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

  private func isCheckboxChecked_NoLock(_ sn: SPIDNodePair) -> Bool {
    if let node = sn.node {
      if node.isEphemeral {
        return false
      }
    }

    if self.checkedNodeSet.contains(sn.spid.nodeUID) {
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
          NSLog("DEBUG Sibling \(siblingSN.spid.guid) == \(DisplayStore.CHECKBOX_STATE_NAMES[state.rawValue])")
          self.updateCheckedStateTracking_NoLock(siblingSN, isChecked: state == .on, isMixed: state == .mixed)
        }
      }
    }
  }

  private func getCheckboxState_NoLock(_ sn: SPIDNodePair) -> NSControl.StateValue {
    if self.isCheckboxChecked_NoLock(sn) {
      return .on
    } else if self.mixedNodeSet.contains(sn.spid.nodeUID) {
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
      isMixed = self.mixedNodeSet.contains(sn.spid.nodeUID)
    }
    return isMixed
  }

  private func updateCheckedStateTracking_NoLock(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    let nodeUID: UID = sn.spid.nodeUID

    NSLog("DEBUG Setting node \(nodeUID): checked=\(isChecked) mixed=\(isMixed)")

    if isChecked {
      self.checkedNodeSet.insert(nodeUID)
    } else {
      self.checkedNodeSet.remove(nodeUID)
    }

    if isMixed {
      self.mixedNodeSet.insert(nodeUID)
    } else {
      self.mixedNodeSet.remove(nodeUID)
    }

  }

  func updateCheckedStateTracking(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    con.app.execSync {
      self.updateCheckedStateTracking_NoLock(sn, isChecked: isChecked, isMixed: isMixed)
    }
  }

  // Other
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func removeSN(_ guid: GUID) -> Bool {
    var removed: Bool = false
    if let sn: SPIDNodePair = self.getSN(guid) {
      let nodeUID = sn.spid.nodeUID
      con.app.execSync {
        self.checkedNodeSet.remove(nodeUID)
        self.mixedNodeSet.remove(nodeUID)
        self.parentChildListDict.removeValue(forKey: guid)

        if self.primaryDict.removeValue(forKey: guid) == nil {
          NSLog("WARN  Could not remove GUID from DisplayStore because it wasn't found: \(guid)")
        } else {
          NSLog("DEBUG GUID removed from DisplayStore: \(guid)")
          removed = true
        }
      }
    }
    return removed
  }

  func isDir(_ guid: GUID) -> Bool {
    return self.getSN(guid)?.node!.isDir ?? false
  }

  func doForSelfAndAllDescendants(_ guid: GUID, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.
    var searchQueue = LinkedList<SPIDNodePair>()

    if var sn = self.getSN_NoLock(guid) {
      NSLog("DEBUG [\(self.con.treeID)] doForSelfAndAllDescendants(): self=\(sn.spid)")
      searchQueue.append(sn)

      while !searchQueue.isEmpty {
        sn = searchQueue.popFirst()!
        NSLog("DEBUG [\(self.con.treeID)] doForSelfAndAllDescendants(): applying func for: \(sn.spid)")
        applyFunc(sn)

        for childSN in self.getChildList_NoLock(sn.spid.guid) {
            searchQueue.append(childSN)
        }
      }
    }
  }
}
