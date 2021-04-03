//
//  DisplayStore.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/21.
//

import Foundation

//class GUINodeIdentifier {
//  let guid: GUID
//  let singlePath: String
//  let uid: UID
//
//  init(_ guid: GUID, _ singlePath: String, _ uid: UID) {
//    self.guid = guid
//    self.singlePath = singlePath
//    self.uid = uid
//  }
//}

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

  func guidFor(_ sn: SPIDNodePair?) -> GUID {
    if sn == nil {
      return NULL_GUID
    }
    let guid = self.guidFor(sn!.spid)
//    NSLog("DEBUG [\(self.con.treeID)] GUID \(guid) => \(sn!.spid.uid) \(sn!.spid.getSinglePath())")
    return guid
  }

  // FIXME: we do not require the path here
  func guidFor(_ spid: SPID) -> GUID {
    return self.guidFor(spid.treeType, singlePath: spid.getSinglePath(), uid: spid.uid)
  }

  private func guidFor(_ treeType: TreeType, singlePath: String, uid: UID) -> GUID {
    return self.con.app.guidFor(treeType, singlePath: singlePath, uid: uid)
  }

  /**
   Derives list of SPIDNodePairs from a list of Nodes and their parent SPID
  */
  func convertChildList(_ parentSN: SPIDNodePair, _ childNodeList: [Node]) throws -> [SPIDNodePair] {
    var childSNList = [SPIDNodePair]()

    let parentPath: String = parentSN.spid.getSinglePath()
    for childNode in childNodeList {
      let singlePath: String = URL(fileURLWithPath: parentPath).appendingPathComponent(childNode.name).path
      let childSPID = try self.con.backend.nodeIdentifierFactory.singlePath(from: childNode.nodeIdentifier, with: singlePath)
      let childSN: SPIDNodePair = (childSPID, childNode)
      childSNList.append(childSN)
    }

    return childSNList
  }

  /**
   Comvert a node to a SPIDNodePair, using data from its parent SPIDNodePair
 */
  func convertSingleNode(_ parentSN: SPIDNodePair?, node: Node) throws -> SPIDNodePair {
    let parentPath: String = parentSN == nil ? self.con.tree.rootPath : parentSN!.spid.getSinglePath()
    let singlePath: String = URL(fileURLWithPath: parentPath).appendingPathComponent(node.name).path
    let childSPID = try self.con.backend.nodeIdentifierFactory.singlePath(from: node.nodeIdentifier, with: singlePath)
    return (childSPID, node)
  }

  /**
   Clears all data structures. Populates the data structures with the given SNs, then returns them.
  */
  func repopulateRoot(_ topLevelSNList: [SPIDNodePair]) -> Void {
    con.app.execSync {
      var nodeDict: [GUID: SPIDNodePair] = [:]
      for sn in topLevelSNList {
        nodeDict[self.guidFor(sn)] = sn
      }

      self.primaryDict = nodeDict
      self.parentChildListDict.removeAll()
      self.parentChildListDict[NULL_GUID] = topLevelSNList
    }
  }

  func populateChildList(_ parentSN: SPIDNodePair?, _ childSNList: [SPIDNodePair]) {
    con.app.execSync {

      for childSN in childSNList {
        self.primaryDict[self.guidFor(childSN)] = childSN
      }
      // note: top-level's parent is 'nil' in OutlineView, but is NULL_GUID in DisplayStore
      let parentGUID = parentSN == nil ? NULL_GUID : self.guidFor(parentSN!)
      self.parentChildListDict[parentGUID] = childSNList
    }
  }

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
