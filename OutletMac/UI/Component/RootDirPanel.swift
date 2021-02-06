//
//  RootDirPanel.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-31.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI

/**
 STRUCT RootDirPanel
 */
struct RootDirPanel: View {
  let con: TreeControllable
  private let dipatchListener: DispatchListener

  @State private var isEditing: Bool = true
  private var canChangeRoot: Bool = false
  // TODO: figure out if we can somehow bind directly to the var
  @State private var needsManualLoad: Bool = false
  @State private var isUIEnabled: Bool = false
  @State private var isRootExists: Bool = false
  @State private var rootPath: String = ""
  private let colors: [Color] = [.gray, .red, .orange, .yellow, .green, .blue, .purple, .pink]
  @State private var fgColor: Color = .gray

  init(controller: TreeControllable, canChangeRoot: Bool) {
    self.con = controller
    let dispatchListenerID = "RootDirPanel-\(self.con.treeID)"
    self.dipatchListener = self.con.dispatcher.createListener(dispatchListenerID)

    NSLog("[\(self.con.treeID)] Setting rootPath to \(controller.tree.rootPath)")
    self.rootPath = controller.tree.rootPath
    self.canChangeRoot = canChangeRoot
    self.isUIEnabled = canChangeRoot
    self.needsManualLoad = self.con.tree.needsManualLoad
    do {
      try start()
    } catch {
      // TODO: what do we do here?
      fatalError("Failed to start RootDirPanel!")
    }
  }

  mutating func start() throws {
    try self.dipatchListener.subscribe(signal: .TOGGLE_UI_ENABLEMENT, self.onEnableUIToggled)
    try self.dipatchListener.subscribe(signal: .LOAD_SUBTREE_STARTED, self.onLoadStarted, whitelistSenderID: self.con.treeID)
    try self.dipatchListener.subscribe(signal: .DISPLAY_TREE_CHANGED, self.onDisplayTreeChanged, whitelistSenderID: self.con.treeID)
    try self.dipatchListener.subscribe(signal: .END_EDITING, self.onEditingCancelled)
  }

  func shutdown() throws {
    try self.dipatchListener.unsubscribeAll()
  }

  func submitRootPath() {
    do {
      _ = try self.con.backend.createDisplayTreeFromUserPath(treeID: self.con.tree.treeID, userPath: self.rootPath)
    } catch {
      NSLog("Failed to submit root path \"\(rootPath)\": \(error)")
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: H_PAD) {
      Image("folder.13-regular-medium")
          .renderingMode(.template)
          .frame(width: 16, height: 16)
          .padding(.leading, H_PAD)
      if !isRootExists {
        // TODO: alert icon
        Image("folder.13-regular-medium")
            .renderingMode(.template)
            .frame(width: 16, height: 16)
            .padding(.leading, H_PAD)
      }

      if isEditing {
        TextField("Enter path...", text: $rootPath, onEditingChanged: { (editingChanged) in
          if editingChanged {
            // we don't use this
          } else {
//            NSLog("[\(self.con.treeID)] TextField focus removed: root path is \(rootPath)")
            // TODO: also bind to Escape key
//            self.isEditing = false

            // TODO: separate this, do for Enter key only
//            self.submitRootPath()
          }
        })
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .background(fgColor)
//          .foregroundColor(Color.blue)
          .onTapGesture(count: 1, perform: {
            fgColor = colors.randomElement()!
          })
        .onExitCommand {
          NSLog("[\(self.con.treeID)] TextField got exit cmd: root path is \(rootPath)")
          self.isEditing = false
        }
        
      } else { // not editing
        Text($rootPath.wrappedValue)
          .background(fgColor)
          .onTapGesture(count: 1, perform: {
            isEditing = true
          })
      }
    }
  }

  // Dispatch Listeners
  // ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼ ▼
  func onEnableUIToggled(_ props: PropDict) throws {
    if !self.canChangeRoot {
      assert(!self.isUIEnabled)
      return
    }
    self.isUIEnabled = try props.getBool("enable")
  }

  func onLoadStarted(_ params: PropDict) throws {
    if self.needsManualLoad {
      self.needsManualLoad = false
    }
  }

  func onDisplayTreeChanged(_ params: PropDict) throws {
    let newTree: DisplayTree = try params.get("tree") as! DisplayTree
    self.rootPath = newTree.rootPath
    self.isRootExists = newTree.rootExists
  }

  func onEditingCancelled(_ params: PropDict) throws {
    NSLog("[\(self.con.treeID)] Editing cancelled")
    self.isEditing = false
  }

}


@available(OSX 11.0, *)
struct RootDirPanel_Previews: PreviewProvider {
  static var previews: some View {
    RootDirPanel(controller: MockTreeController(ID_LEFT_TREE), canChangeRoot: true)
  }
}

struct RootDirPanel_Previews_2: PreviewProvider {
  static var previews: some View {
    /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
  }
}
