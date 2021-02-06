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
  @ObservedObject var uiState: TreeSwiftState

  private let colors: [Color] = [.gray, .red, .orange, .yellow, .green, .blue, .purple, .pink]
  @State private var fgColor: Color = .gray

  init(controller: TreeControllable, canChangeRoot: Bool) {
    self.con = controller
    self.uiState = self.con.uiState
  }

  func submitRootPath() {
    do {
      _ = try self.con.backend.createDisplayTreeFromUserPath(treeID: self.con.tree.treeID, userPath: self.uiState.rootPath)
    } catch {
      NSLog("Failed to submit root path \"\(self.uiState.rootPath)\": \(error)")
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: H_PAD) {
      Image("folder.13-regular-medium")
          .renderingMode(.template)
          .frame(width: 16, height: 16)
          .padding(.leading, H_PAD)
      if !self.uiState.isRootExists {
        // TODO: alert icon
        Image("folder.13-regular-medium")
            .renderingMode(.template)
            .frame(width: 16, height: 16)
            .padding(.leading, H_PAD)
      }

      if self.uiState.isEditingRoot {
        TextField("Enter path...", text: $uiState.rootPath, onEditingChanged: { (editingChanged) in
          if editingChanged {
            // we don't care about this
          } else {
            // This is ENTER key
            NSLog("[\(self.con.treeID)] DEBUG TextField focus removed (assuming ENTER key pressed): submitting root path")

            self.submitRootPath()
            self.uiState.isEditingRoot = false
          }
        })
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .background(fgColor)
          .onTapGesture(count: 1, perform: {
            // No op. Just override default
          })
        .onExitCommand {
          NSLog("[\(self.con.treeID)] DEBUG TextField got exit cmd")
          self.con.dispatcher.sendSignal(signal: .CANCEL_EDIT_ROOT, senderID: ID_MAIN_WINDOW)
        }
        
      } else { // not editing
        Text(self.uiState.rootPath)
          .background(fgColor)
          .onTapGesture(count: 1, perform: {
            // switch to Editing mode
            self.uiState.isEditingRoot = true
          })
      }
    }
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
