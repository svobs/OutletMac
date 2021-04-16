//
//  DisplayStore.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/21.
//

import Foundation

/**
 I suppose this class a repository for "ModelView" objects in the MVVC design pattern.
 */
class DisplayStore {
  private var con: TreePanelControllable

  private var parentChildListDict: [GUID: [SPIDNodePair]] = [:]
  private var primaryDict: [GUID: SPIDNodePair] = [:]

  init(_ controllable: TreePanelControllable) {
    self.con = controllable
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

      self.primaryDict = nodeDict
      self.parentChildListDict.removeAll()
      self.parentChildListDict[NULL_GUID] = topLevelSNList
    }
  }

  func putChildList(_ parentSN: SPIDNodePair?, _ childSNList: [SPIDNodePair]) {
    con.app.execSync {

      for childSN in childSNList {
        self.primaryDict[childSN.spid.guid] = childSN
      }
      // note: top-level's parent is 'nil' in OutlineView, but is NULL_GUID in DisplayStore
      let parentGUID = parentSN == nil ? NULL_GUID : parentSN!.spid.guid
      self.parentChildListDict[parentGUID] = childSNList
    }
  }

  // "Get" operations
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼

  func getSN(_ guid: GUID) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    con.app.execSync {
      sn = self.primaryDict[guid] ?? nil
    }
    return sn
  }

  func getChildListForRoot() -> [SPIDNodePair] {
    return self.getChildList(nil)
  }

  func getChildList(_ parentGUID: GUID?) -> [SPIDNodePair] {
    var snList: [SPIDNodePair] = []
    con.app.execSync {
      snList = self.parentChildListDict[parentGUID ?? NULL_GUID] ?? []
    }
    return snList
  }

  func getChild(_ parentGUID: GUID?, _ childIndex: Int) -> SPIDNodePair? {
    var sn: SPIDNodePair?
    con.app.execSync {
      let childList = self.parentChildListDict[parentGUID ?? NULL_GUID] ?? []
      if childIndex >= childList.count {
        NSLog("ERROR Could not find child of parent GUID \(parentGUID ?? NULL_GUID) & index \(childIndex)")
        sn = nil
      } else {
        sn = childList[childIndex]
      }
    }
    return sn
  }

  func isDir(_ guid: GUID) -> Bool {
    return self.getSN(guid)?.node!.isDir ?? false
  }
}
