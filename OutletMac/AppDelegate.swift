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
        let grpcClient: OutletGRPCClient = OutletGRPCClient.makeClient(host: "localhost", port: 50051)
        NSLog("gRPC client connected!")
        
        let request: DisplayTreeRequest = DisplayTreeRequest(treeId: ID_LEFT_TREE, returnAsync: false, isStartup: true)
        let displayTree: DisplayTree = try grpcClient.requestDisplayTree(request)!
        do {
          NSLog("Sleeping 4...")
          sleep(4)
          NSLog("Quitting")
          exit(0)
        }
      } catch {
        NSLog("RPC failed: \(error)")
        fatalError()
      }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

