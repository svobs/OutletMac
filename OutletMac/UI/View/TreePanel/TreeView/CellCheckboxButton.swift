//
//  CellCheckboxButton.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/5/6.
//  Copyright © 2021 Matt Svoboda. All rights reserved.
//

import Foundation
import AppKit

class CellCheckboxButton: NSButton {
  let parent: TreeViewController
  var guid: GUID

  var treeID: TreeID {
    get {
      return parent.treeID
    }
  }

  var displayStore: DisplayStore {
    get {
      return parent.displayStore
    }
  }

  init(sn: SPIDNodePair, parent: TreeViewController) {
    self.parent = parent
    self.guid = sn.spid.guid
    // NOTE: *MUST* use this constructor when subclassing. All other constructors will crash at runtime.
    // Thanks Apple!
    super.init(frame: NSRect(x: 150, y: 200, width: 20, height: 20))
    self.title = ""
    self.action = #selector(self.onCellCheckboxToggled(_:))
    self.target = parent
    self.setButtonType(.switch)
    self.bezelStyle = .texturedRounded
    self.translatesAutoresizingMaskIntoConstraints = false

    self.updateState(sn)
  }

  func updateState(_ sn: SPIDNodePair) {
    self.guid = sn.spid.guid
    let state = self.parent.displayStore.getCheckboxState(sn)
    if state == .mixed {
        self.allowsMixedState = true
    }
    self.state = state
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /**
   Post button click
 */
  @objc func onCellCheckboxToggled(_ sender: CellCheckboxButton) {
    assert(sender.state.rawValue != -1, "User should never be allowed to toggle checkbox into Mixed state!")
    let isChecked = sender.state.rawValue == 1
    NSLog("DEBUG [\(treeID)] User toggled checkbox for: \(sender.guid) => \(isChecked)")

    // If checkbox was previously in Mixed state, it is now either Off or On. But we need to actively
    // prevent them from toggling it into Mixed again.
    sender.allowsMixedState = false

    guard let sn = self.displayStore.getSN(sender.guid) else {
      self.parent.con.reportError("Internal Error", "Could not toggle checkbox: could not find SN in DisplayStore for GUID \(sender.guid)")
      return
    }
    if let isEphemeral = sn.node?.isEphemeral {
      if isEphemeral {
        return
      }
    }

    let newIsCheckedValue: Bool = !self.displayStore.isCheckboxChecked(sn)
    NSLog("DEBUG [\(treeID)] Setting new checked value for node_uid: \(sn.spid.nodeUID) => \(newIsCheckedValue)")
    self.setNodeCheckedState(sender.guid, newIsCheckedValue)
  }

  private func setCheckedState(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    let guid = sn.spid.guid
    NSLog("DEBUG [\(treeID)] Updating checkbox state of: \(guid) (\(sn.spid)) => \(isChecked)/\(isMixed)")

    // Update model here:
    self.displayStore.updateCheckedStateTracking(sn, isChecked: isChecked, isMixed: isMixed)

    // Now update the node in the UI:
    self.parent.reloadItem(guid, reloadChildren: false)
  }

  func setNodeCheckedState(_ guid: GUID, _ newIsCheckedValue: Bool) {
    /*
     1. Siblings

     Housekeeping. Need to update all the siblings (children of parent) because their checked state may not be tracked.
     We can assume that if a parent is not mixed (i.e. is either checked or unchecked), the state of its children are implied.
     But if the parent is mixed, we must track the state of ALL of its children.
     */
    let parentGUID = self.displayStore.getParentGUID(guid)!
    NSLog("DEBUG [\(treeID)] setNodeCheckedState(): checking siblings of \(guid) (parent_guid=\(parentGUID))")
    if parentGUID != TOPMOST_GUID {
      for siblingSN in self.displayStore.getChildList(parentGUID) {
        let state = self.displayStore.getCheckboxState(siblingSN)
        self.displayStore.updateCheckedStateTracking(siblingSN, isChecked: state == .on, isMixed: state == .mixed)
      }
    }

    /*
     2. Children
     Need to update all the children of the node to match its checked state, both in UI and tracking.
     */
    NSLog("DEBUG [\(treeID)] setNodeCheckedState(): checking self and descendants of \(guid)")
    let applyFunc: ApplyToSNFunc = { sn in self.setCheckedState(sn, isChecked: newIsCheckedValue, isMixed: false) }
    self.displayStore.doForSelfAndAllDescendants(guid, applyFunc)

    /*
     3. Ancestors: need to update all direct ancestors, but take into account all of the children of each.
     */
    NSLog("DEBUG [\(treeID)] setNodeCheckedState(): checking ancestors of \(guid)")
    var ancestorGUID: GUID = guid
    while true {
      ancestorGUID = self.displayStore.getParentGUID(ancestorGUID)!
      NSLog("DEBUG [\(treeID)] setNodeCheckedState(): next higher ancestor: \(ancestorGUID)")
      if ancestorGUID == TOPMOST_GUID {
        break
      }
      var hasChecked = false
      var hasUnchecked = false
      var hasMixed = false
      for childSN in self.displayStore.getChildList(ancestorGUID) {
        if self.displayStore.isCheckboxChecked(childSN) {
          hasChecked = true
        } else {
          hasUnchecked = true
        }
        hasMixed = hasMixed || self.displayStore.isCheckboxMixed(childSN)
      }
      let isChecked = hasChecked && !hasUnchecked && !hasMixed
      let isMixed = hasMixed || (hasChecked && hasUnchecked)
      let ancestorSN = self.displayStore.getSN(ancestorGUID)
      self.setCheckedState(ancestorSN!, isChecked: isChecked, isMixed: isMixed)
    }
  }

}
