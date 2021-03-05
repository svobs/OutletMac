//
//  AppDelegate.swift
//  OutlineView
//
//  Created by Toph Allen on 4/13/20.
//  Copyright © 2020 Toph Allen. All rights reserved.
//
import AppKit
import Cocoa
import SwiftUI

/**
 PROTOCOL OutletApp
 */
protocol OutletApp {
  var dispatcher: SignalDispatcher { get }
  var backend: OutletBackend { get }

  func execAsync(_ workItem: @escaping NoArgVoidFunc)
  func execSync(_ workItem: @escaping NoArgVoidFunc)
}

class MockApp: OutletApp {
  var dispatcher: SignalDispatcher
  var backend: OutletBackend

  init() {
    self.dispatcher = SignalDispatcher()
    self.backend = MockBackend(self.dispatcher)
  }

  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
  }
  func execSync(_ workItem: @escaping NoArgVoidFunc) {
  }
}

class OutletMacApp: NSObject, NSApplicationDelegate, NSWindowDelegate, OutletApp {
  var preferencesWindow: NSWindow!
  var window: NSWindow!

  let winID = ID_MAIN_WINDOW
  let settings = GlobalSettings()
  let dispatcher = SignalDispatcher()
  // TODO: surely Swift has a better way to init these
  var dispatchListener: DispatchListener? = nil
  var _backend: OutletBackend? = nil
  var conLeft: TreeController? = nil
  var conRight: TreeController? = nil
  var taskRunner: TaskRunner = TaskRunner()

  var backend: OutletBackend {
    get {
      return self._backend!
    }
  }

  func do_init() {
    NSLog("DEBUG OutletMacApp init begin")

    do {
      self._backend = OutletGRPCClient.makeClient(host: "localhost", port: 50051, dispatcher: self.dispatcher)

      NSLog("INFO  gRPC client connecting")
      try self.backend.start()
      NSLog("INFO  Backend started")

      // Subscribe to app-wide signals here
      dispatchListener = dispatcher.createListener(winID)
      try dispatchListener!.subscribe(signal: .ERROR_OCCURRED, onErrorOccurred)
      try dispatchListener!.subscribe(signal: .OP_EXECUTION_PLAY_STATE_CHANGED, onOpExecutionPlayStateChanged)

      let xLocConfigPath = "ui_state.\(winID).x"
      let yLocConfigPath = "ui_state.\(winID).y"
      let winX : Int = try self.backend.getIntConfig(xLocConfigPath)
      let winY : Int = try self.backend.getIntConfig(yLocConfigPath)

      let widthConfigPath = "ui_state.\(winID).width"
      let heightConfigPath = "ui_state.\(winID).height"
      let winWidth : Int = try backend.getIntConfig(widthConfigPath)
      let winHeight : Int = try backend.getIntConfig(heightConfigPath)

      NSLog("DEBUG WinCoords: (\(winX), \(winY)), width/height: \(winWidth)x\(winHeight)")

      settings.isPlaying = try self.backend.getOpExecutionPlayState()

      // TODO: eventually refactor this so that all state is stored in BE, and we only supply the tree_id when we request the state
      let treeLeft: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_LEFT_TREE, isStartup: true)!
      let treeRight: DisplayTree = try backend.createDisplayTreeFromConfig(treeID: ID_RIGHT_TREE, isStartup: true)!
      let filterCriteriaLeft: FilterCriteria = try backend.getFilterCriteria(treeID: ID_LEFT_TREE)
      let filterCriteriaRight: FilterCriteria = try backend.getFilterCriteria(treeID: ID_RIGHT_TREE)
      self.conLeft = TreeController(app: self, tree: treeLeft, filterCriteria: filterCriteriaLeft)
      self.conRight = TreeController(app: self, tree: treeRight, filterCriteria: filterCriteriaRight)

      try conLeft!.start()
      try conLeft!.loadTree()
      try conRight!.start()
      try conRight!.loadTree()

      let screenSize = NSScreen.main?.frame.size ?? .zero
      NSLog("DEBUG Screen size is \(screenSize.width)x\(screenSize.height)")

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
      NSLog("DEBUG Sleeping 1s to let things settle...")
      sleep(1)
      exit(1)
    }
    NSLog("DEBUG OutletMacApp init done")

  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("START app")
    self.do_init()

    window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
//    let contentSize = NSSize(width:800, height:600)
//    window.setContentSize(contentSize)
//    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
//    window.level = .floating
    window.delegate = self
    window.title = "TestView"

    let contentView = ContentView(app: self, conLeft: self.conLeft!, conRight: self.conRight!).environmentObject(self.settings)
    window.contentView = NSHostingView(rootView: contentView)
    window.center()
    window.makeKeyAndOrderFront(nil)
  }
  class WindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
      NSApplication.shared.terminate(0)
    }
  }

  @objc func windowDidResize(_ notification: Notification) {
    NSLog("WINDOW DID RESIZE !!!!!!!!!!!!!!!!!")
  }

  @objc func windowWillClose(_ notification: Notification) {
    NSLog("windowWillClose ..................................................")
  }

  @objc func openPreferencesWindow() {
    if nil == preferencesWindow {      // create once !!
      let preferencesView = PrefsView()
      // Create the preferences window and set content
      preferencesWindow = NSWindow(
        contentRect: NSRect(x: 20, y: 20, width: 480, height: 300),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false)
      preferencesWindow.center()
      preferencesWindow.setFrameAutosaveName("Preferences")
      preferencesWindow.isReleasedWhenClosed = false
      preferencesWindow.contentView = NSHostingView(rootView: preferencesView)
    }
    preferencesWindow.makeKeyAndOrderFront(nil)
  }

  // Displays any errors that are reported from the backend via gRPC
  func onErrorOccurred(senderID: SenderID, propDict: PropDict) throws {
    let msg = try propDict.getString("msg")
    let secondaryMsg = try propDict.getString("secondary_msg")
    DispatchQueue.main.async {
      self.settings.showAlert(title: msg, msg: secondaryMsg)
    }
  }

  func onOpExecutionPlayStateChanged(senderID: SenderID, propDict: PropDict) throws {
    let isEnabled = try propDict.getBool("is_enabled")
    DispatchQueue.main.async {
      self.settings.isPlaying = isEnabled
    }
  }

  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
    self.taskRunner.execAsync(workItem)
  }

  func execSync(_ workItem: @escaping NoArgVoidFunc) {
    self.taskRunner.execSync(workItem)
  }
}
