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
  @State var isEditing: Bool = false
  var canChangeRoot: Bool
  var isRootExists: Bool = false
  @State var rootPath: String = "/usr/path"
  let colors: [Color] = [.gray, .red, .orange, .yellow,
                             .green, .blue, .purple, .pink]
  @State private var fgColor: Color = .gray

  init(controller: TreeControllable, canChangeRoot: Bool) {
    self.con = controller
    self.canChangeRoot = canChangeRoot
  }

  func submitRootPath() {
    do {
      try self.con.backend.createDisplayTreeFromUserPath(treeID: self.con.tree.treeID, userPath: self.rootPath)
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
            NSLog("TextField focus removed: root path is \(rootPath)")
            // TODO: also bind to Escape key
            self.isEditing = false

            // TODO: separate this, do for Enter key only
            self.submitRootPath()
          }
        })
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .background(fgColor)
//          .foregroundColor(Color.blue)
          .onTapGesture(count: 1, perform: {
                          fgColor = colors.randomElement()!
                      })
        .onExitCommand {
          NSLog("TextField got exit cmd: root path is \(rootPath)")
          self.isEditing = false
        }
        
      } else {
        Text(rootPath)
          .background(fgColor)
          .onTapGesture(count: 1, perform: {
            isEditing = true
                      })
      }
    }
  }
}

@available(OSX 11.0, *)
struct RootDirPanel_Previews: PreviewProvider {
  static var previews: some View {
    RootDirPanel(controller: NullTreeController(ID_LEFT_TREE), canChangeRoot: true)
  }
}

struct RootDirPanel_Previews_2: PreviewProvider {
  static var previews: some View {
    /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
  }
}
