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

/**
 CLASS AppDelegate
 */
@available(OSX 11.0, *)
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, OutletApp {

  var window: NSWindow!
  let dispatcher = SignalDispatcher()
  var backend: OutletBackend? = nil

//  static func endEditing() {
//      sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//  }
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {

    do {

      let backendGRPC = OutletGRPCClient.makeClient(host: "localhost", port: 50051, dispatcher: self.dispatcher)
      self.backend = backendGRPC
      NSLog("gRPC client connecting")

      try self.backend!.start()

      let win_id = ID_DIFF_WINDOW
      let xLocConfigPath = "ui_state.\(win_id).x"
      let yLocConfigPath = "ui_state.\(win_id).y"
      let winX : Int = try self.backend!.getIntConfig(xLocConfigPath)
      let winY : Int = try self.backend!.getIntConfig(yLocConfigPath)

      let widthConfigPath = "ui_state.\(win_id).width"
      let heightConfigPath = "ui_state.\(win_id).height"
      let winWidth : Int = try backend!.getIntConfig(widthConfigPath)
      let winHeight : Int = try backend!.getIntConfig(heightConfigPath)

      NSLog("WinCoords: (\(winX), \(winY)), width/height: \(winWidth)x\(winHeight)")

      let treeLeft: DisplayTree = try backend!.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try backend!.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      let conLeft = TreeController(app: self, tree: treeLeft)
      let conRight = TreeController(app: self, tree: treeRight)

      // Create the SwiftUI view that provides the window contents.
      let contentView = ContentView(app: self, conLeft: conLeft, conRight: conRight)
      
      // Create the window and set the content view.
      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false)
      window.center()
      window.setFrameAutosaveName("OutletMac")
      window.contentView = NSHostingView(rootView: contentView)
      window.makeKeyAndOrderFront(nil)


//      NSLog("Sleeping 2...")
//      sleep(2)
//      NSLog("Quitting")
//      exit(0)
    } catch {
      fatalError("Fatal error: \(error)")
    }
  }
  
  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }
  
  
}

