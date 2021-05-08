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
    self.target = self
    self.setButtonType(.switch)
    self.bezelStyle = .texturedRounded
    self.translatesAutoresizingMaskIntoConstraints = false

    self.updateState(sn)
  }

  func updateState(_ sn: SPIDNodePair) {
    self.guid = sn.spid.guid
    let state = self.parent.displayStore.getCheckboxState(sn)
    // Need to disable this in most cases, because we cannot preemptively prevent the user from
    // toggling into the Mixed state if it is enabled. Enable only when we want to display the mixed state:
    self.allowsMixedState = state == .mixed
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
    let guid: GUID = sender.guid
    NSLog("DEBUG [\(treeID)] User toggled checkbox for: \(guid) => \(isChecked)")

    // If checkbox was previously in Mixed state, it is now either Off or On. But we need to actively
    // prevent them from toggling it into Mixed again.
    sender.allowsMixedState = false

    guard let sn = self.displayStore.getSN(guid) else {
      self.parent.con.reportError("Internal Error", "Could not toggle checkbox: could not find SN in DisplayStore for GUID \(guid)")
      return
    }
    if let isEphemeral = sn.node?.isEphemeral {
      if isEphemeral {
        return
      }
    }

    // What a mouthful. At least we are handling the bulk of the work in one batch:
    self.displayStore.updateCheckboxStateForSameLevelAndBelow(guid, isChecked, self.treeID)
    // Now update all of those in the UI:
    self.parent.reloadItem(guid, reloadChildren: true)

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
      NSLog("DEBUG [\(treeID)] Ancestor: \(ancestorGUID) hasChecked=\(hasChecked) hasUnchecked=\(hasUnchecked) hasMixed=\(hasMixed) => isChecked=\(isChecked) isMixed=\(isMixed)")
      self.setCheckedState(ancestorSN!, isChecked: isChecked, isMixed: isMixed)
    }
  }

  private func setCheckedState(_ sn: SPIDNodePair, isChecked: Bool, isMixed: Bool) {
    let guid = sn.spid.guid
    NSLog("DEBUG [\(treeID)] Updating checkbox state of: \(guid) (\(sn.spid)) => \(isChecked)/\(isMixed)")

    // Update model here:
    self.displayStore.updateCheckedStateTracking(sn, isChecked: isChecked, isMixed: isMixed)

    // Now update the node in the UI:
    self.parent.reloadItem(guid, reloadChildren: false)
  }

}
