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
  let parent: TreeNSViewController
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

  init(sn: SPIDNodePair, parent: TreeNSViewController) {
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
    let state = self.parent.displayStore.getCheckboxState(guid)
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

    do {
      try self.parent.con.setChecked(guid, isChecked)
    } catch {
      self.parent.con.reportException("Error while toggling checkbox", error)
    }
  }

}
