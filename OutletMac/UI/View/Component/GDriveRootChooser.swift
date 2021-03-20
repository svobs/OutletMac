//
//  GDrivePathSelectionDialog.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/20.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

// TODO: from https://troz.net/post/2019/swiftui-for-mac-2/
struct GDriveRootChooser: View {
  var window: NSWindow!
  @State var windowDelegate = GDriveRootChooserDelegate()
  let treeID: String

  var body: some View {
    Text("Hello, \(treeID)!")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  var isOpen: Bool {
    get {
      return windowDelegate.windowIsOpen
    }
  }

  init(_ treeID: String) {
    self.treeID = treeID
    window = NSWindow()
    window.title = "Google Drive Root Chooser"
    // note: x & y are from lower-left corner
    window.setFrame(NSRect(x: 200, y: 200, width: 400, height: 200), display: true)
    window.contentView = NSHostingView(rootView: self)
    window.delegate = windowDelegate
    window.makeKeyAndOrderFront(nil)
  }

  class GDriveRootChooserDelegate: NSObject, NSWindowDelegate {
    var windowIsOpen = true

    func windowWillClose(_ notification: Notification) {
      windowIsOpen = false
    }
  }
}
