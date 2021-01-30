//
//  AppDelegate.swift
//  OutlineView
//
//  Created by Toph Allen on 4/13/20.
//  Copyright © 2020 Toph Allen. All rights reserved.
//

import Cocoa
import SwiftUI

@available(OSX 11.0, *)
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  
  var window: NSWindow!
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Create the SwiftUI view that provides the window contents.
    let contentView = ContentView()
    
    // Create the window and set the content view.
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.center()
    window.setFrameAutosaveName("OutletMac")
    window.contentView = NSHostingView(rootView: contentView)
    window.makeKeyAndOrderFront(nil)
    
    do {
      let backend: OutletGRPCClient = OutletGRPCClient.makeClient(host: "localhost", port: 50051)
      NSLog("gRPC client connecting")
      backend.receiveServerSignals()
      
      let win_id = ID_DIFF_WINDOW
      let xLocConfigPath = "ui_state.\(win_id).x"
      let yLocConfigPath = "ui_state.\(win_id).y"
      let winX : Int = try backend.getIntConfig(xLocConfigPath)
      let winY : Int = try backend.getIntConfig(yLocConfigPath)
      
      let widthConfigPath = "ui_state.\(win_id).width"
      let heightConfigPath = "ui_state.\(win_id).height"
      let winWidth : Int = try backend.getIntConfig(widthConfigPath)
      let winHeight : Int = try backend.getIntConfig(heightConfigPath)
      
      NSLog("WinCoords: (\(winX), \(winY)), width/height: \(winWidth)x\(winHeight)")
      
      let treeLeft: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      
      NSLog("Sleeping 2...")
      sleep(2)
      NSLog("Quitting")
      exit(0)
    } catch {
      fatalError("RPC failed: \(error)")
    }
  }
  
  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }
  
  
}

