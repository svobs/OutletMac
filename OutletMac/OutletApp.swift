//
//  AppDelegate.swift
//  OutlineView
//
//  Created by Toph Allen on 4/13/20.
//  Copyright © 2020 Toph Allen. All rights reserved.
//

import Cocoa
import SwiftUI

/**
 PROTOCOL OutletApp
 */
protocol OutletApp {
  var dispatcher: SignalDispatcher { get }
  var backend: OutletBackend? { get }
}

class MockApp: OutletApp {
  var dispatcher: SignalDispatcher
  var backend: OutletBackend?

  init() {
    self.dispatcher = SignalDispatcher()
    self.backend = MockBackend(self.dispatcher)
  }
}

@main
struct OutletMacApp: App, OutletApp {
  let winID = ID_DIFF_WINDOW
  let settings = GlobalSettings()
  let dispatcher = SignalDispatcher()
  var dispatchListener: DispatchListener? = nil
  var backend: OutletBackend? = nil
  var conLeft: TreeController? = nil
  var conRight: TreeController? = nil

  init() {
    NSLog("OutletMacApp init begin")
    do {
      let backendGRPC = OutletGRPCClient.makeClient(host: "localhost", port: 50051, dispatcher: self.dispatcher)
      self.backend = backendGRPC
      NSLog("gRPC client connecting")
      try self.backend!.start()
      NSLog("Backend started")

      let xLocConfigPath = "ui_state.\(winID).x"
      let yLocConfigPath = "ui_state.\(winID).y"
      let winX : Int = try self.backend!.getIntConfig(xLocConfigPath)
      let winY : Int = try self.backend!.getIntConfig(yLocConfigPath)

      let widthConfigPath = "ui_state.\(winID).width"
      let heightConfigPath = "ui_state.\(winID).height"
      let winWidth : Int = try backend!.getIntConfig(widthConfigPath)
      let winHeight : Int = try backend!.getIntConfig(heightConfigPath)

      NSLog("WinCoords: (\(winX), \(winY)), width/height: \(winWidth)x\(winHeight)")

      dispatchListener = dispatcher.createListener(winID)
      try dispatchListener!.subscribe(signal: .ERROR_OCCURRED, onErrorOccurred)

      let treeLeft: DisplayTree = try backend!.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try backend!.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      let filterCriteriaLeft: FilterCriteria = try backend!.getFilterCriteria(treeID: ID_LEFT_TREE)
      let filterCriteriaRight: FilterCriteria = try backend!.getFilterCriteria(treeID: ID_RIGHT_TREE)
      self.conLeft = TreeController(app: self, tree: treeLeft, filterCriteria: filterCriteriaLeft)
      self.conRight = TreeController(app: self, tree: treeRight, filterCriteria: filterCriteriaRight)

      try conLeft!.start()
      try conRight!.start()

      let screenSize = NSScreen.main?.frame.size ?? .zero
      NSLog("Screen size is \(screenSize.width)x\(screenSize.height)")

//      // Create the window and set the content view.
//      window = NSWindow(
//        contentRect: NSRect(x: winX, y: winY, width: winWidth, height: winHeight),
//        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
//        backing: .buffered, defer: false)
//      window.center()
//      window.title = "OutletMac"
//      window.setFrameAutosaveName("OutletMac")
//      window.contentView = NSHostingView(rootView: contentView)
//      window.makeKeyAndOrderFront(nil)

//      NSLog("Sleeping 3...")
//      sleep(3)
//      NSLog("Quitting")
//      exit(0)

    } catch {
      NSLog("FATAL ERROR in main(): \(error)")
      NSLog("Sleeping 1s to let things settle...")
      sleep(1)
      exit(1)
    }
    NSLog("OutletMacApp init done")
  }

  func onErrorOccurred(senderID: SenderID, propDict: PropDict) throws {
    try settings.showAlert(title: propDict.getString("msg"), msg: propDict.getString("secondary_msg"))
  }

  var body: some Scene {
    WindowGroup("Outlet") {
      ContentView(app: self, conLeft: self.conLeft!, conRight: self.conRight!)
        .environmentObject(self.settings)
        .frame(width: 800, height: 800)
        .frame(minWidth: 800, maxWidth: .infinity,
               minHeight: 400, maxHeight: .infinity)
    }
  }
}
