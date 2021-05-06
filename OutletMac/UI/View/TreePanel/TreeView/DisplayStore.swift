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
  private var con: TreePanelControllable

  private var parentChildListDict: [GUID: [SPIDNodePair]] = [:]
  private var primaryDict: [GUID: SPIDNodePair] = [:]

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

  private func appendToParentChildDict(parentGUID: GUID?, _ childSN: SPIDNodePair) {
    var realParentGUID: GUID = (parentGUID == nil) ? TOPMOST_GUID : parentGUID!
    if realParentGUID == self.con.tree.rootSPID.guid {
      realParentGUID = TOPMOST_GUID
    }

    // note: top-level's parent is 'nil' in OutlineView, but is TOPMOST_GUID in DisplayStore
    if self.parentChildListDict[realParentGUID] == nil {
      self.parentChildListDict[realParentGUID] = []
    }
    // TODO: this may get slow for very large directories...
    for (index, existing) in self.parentChildListDict[realParentGUID]!.enumerated() {
      if existing.spid.guid == childSN.spid.guid {
        // found: replace existing
        self.parentChildListDict[realParentGUID]![index] = childSN
        return
      }
    }
    self.parentChildListDict[realParentGUID]!.append(childSN)
  }

  // "Put" operations
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  /**
   Clears all data structures. Populates the data structures with the given SNs, then returns them.
  */
  func putRootChildList(_ topLevelSNList: [SPIDNodePair]) -> Void {
    con.app.execSync {
      var nodeDict: [GUID: SPIDNodePair] = [:]
      for sn in topLevelSNList {
        nodeDict[sn.spid.guid] = sn
      }

      self.parentChildListDict.removeAll()
      self.parentChildListDict[TOPMOST_GUID] = topLevelSNList
      self.primaryDict = nodeDict
      self.checkedNodeSet.removeAll()
      self.mixedNodeSet.removeAll()
    }
  }

  func putChildList(_ parentSN: SPIDNodePair?, _ childSNList: [SPIDNodePair]) {
    con.app.execSync {

      for childSN in childSNList {
        self.primaryDict[childSN.spid.guid] = childSN
      }
      // note: top-level's parent is 'nil' in OutlineView, but is TOPMOST_GUID in DisplayStore
      let parentGUID = parentSN == nil ? TOPMOST_GUID : parentSN!.spid.guid
      self.parentChildListDict[parentGUID] = childSNList
    }
  }

  func upsertSN(_ parentGUID: GUID?, _ childSN: SPIDNodePair) -> Bool {
    var wasPresent: Bool = false
    con.app.execSync {
      if self.primaryDict[childSN.spid.guid] != nil {
        wasPresent = true
      }
      self.primaryDict[childSN.spid.guid] = childSN
      self.appendToParentChildDict(parentGUID: parentGUID, childSN)
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

  private func getChildListNoLock(_ parentGUID: GUID?) -> [SPIDNodePair] {
    return self.parentChildListDict[parentGUID ?? TOPMOST_GUID] ?? []
  }

  func getChildList(_ parentGUID: GUID?) -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    con.app.execSync {
      snList = self.getChildListNoLock(parentGUID)
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

  /** Returns (isChecked, isMixed) */
  func getCheckboxState(nodeUID: UID) -> NSControl.StateValue {
    var state: NSControl.StateValue = .off
    con.app.execSync {
      if self.checkedNodeSet.contains(nodeUID) {
        state = .on
      } else if self.mixedNodeSet.contains(nodeUID) {
        state = .mixed
      } else {
        state = .off
      }
    }
    return state
  }

  func isCheckboxChecked(nodeUID: UID) -> Bool {
    var isChecked: Bool = false
    con.app.execSync {
      isChecked = self.checkedNodeSet.contains(nodeUID)
    }
    return isChecked
  }

  func isCheckboxMixed(nodeUID: UID) -> Bool {
    var isMixed: Bool = false
    con.app.execSync {
      isMixed = self.mixedNodeSet.contains(nodeUID)
    }
    return isMixed
  }

  func updateCheckedStateTracking(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    let nodeUID: UID = sn.spid.nodeUID

    con.app.execSync {
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
  }

  func doForSelfAndAllDescendants(_ guid: GUID, _ applyFunc: ApplyToSNFunc) {
    // First construct a deque of all nodes. I'm doing this to avoid possibly nesting dispatch queue work items, since it's possible
    // (likely?) that 'applyFunc' also contains a dispatch queue work item.

    var searchQueue = LinkedList<SPIDNodePair>()
    var workQueue = LinkedList<SPIDNodePair>()

    con.app.execSync {
      if var sn = self.getSN_NoLock(guid) {
        searchQueue.append(sn)
        workQueue.append(sn)

        while !searchQueue.isEmpty {
          sn = searchQueue.popFirst()!
          for childSN in self.getChildListNoLock(sn.spid.guid) {
              searchQueue.append(childSN)
              workQueue.append(childSN)
          }
        }
      }
    }

    while !workQueue.isEmpty {
      let sn = workQueue.popFirst()!
      applyFunc(sn)
    }
  }
}
