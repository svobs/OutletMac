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
  @ObservedObject var swiftTreeState: SwiftTreeState
  let con: TreeControllable

  private let colors: [Color] = [.gray, .red, .orange, .yellow, .green, .blue, .purple, .pink]
  @State private var fgColor: Color = .gray

  init(controller: TreeControllable, canChangeRoot: Bool) {
    self.con = controller
    self.swiftTreeState = self.con.swiftTreeState
  }

  func submitRootPath() {
    do {
      _ = try self.con.backend.createDisplayTreeFromUserPath(treeID: self.con.tree.treeID, userPath: self.swiftTreeState.rootPath)
    } catch {
      NSLog("Failed to submit root path \"\(self.swiftTreeState.rootPath)\": \(error)")
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: H_PAD) {
      Image(systemName: "folder")
        .renderingMode(.template)
        .frame(width: 32, height: 32)
        .padding(.leading, H_PAD)
        .font(Font.system(.title))
        .contextMenu {
          // TODO!
          Button("Local filesystem subtree...", action: {})
          Button("Google Drive subtree...", action: {})
        }

      if !self.swiftTreeState.isRootExists {
        Image(systemName: "exclamationmark.triangle.fill")
          .renderingMode(.template)
          .frame(width: 32, height: 32)
          .padding(.leading, H_PAD)
          .font(Font.system(.title))
      }

      if self.swiftTreeState.isEditingRoot {

        // IS EDITING
        TextField("Enter path...", text: $swiftTreeState.rootPath, onEditingChanged: { (editingChanged) in
          if editingChanged {
            // we don't care about this
          } else {
            // This is ENTER key
            NSLog("[\(self.con.treeID)] DEBUG TextField focus removed (assuming ENTER key pressed): submitting root path")

            self.submitRootPath()
            self.swiftTreeState.isEditingRoot = false
          }
        })
          .font(Font.system(.title))
//        .foregroundColor(.pink)
//        .background(Color.white)
          .onTapGesture(count: 1, perform: {
            // No op. Just override default
          })
        .onExitCommand {
          NSLog("[\(self.con.treeID)] DEBUG TextField got exit cmd")
          self.con.dispatcher.sendSignal(signal: .CANCEL_ALL_EDIT_ROOT, senderID: ID_MAIN_WINDOW)
        }
        
      } else {
        // NOT EDITING

        HStack(spacing: H_PAD) {
          if self.swiftTreeState.rootPath.isEmpty {
            Text("No path entered")
              .italic()
              .multilineTextAlignment(.leading)
              .font(Font.system(.title))
          } else {
            Text(self.swiftTreeState.rootPath)
              .multilineTextAlignment(.leading)
              .font(Font.system(.title))
          }
          Spacer() // this will align the preceding Text object to the left
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle()) // taps should be detected in the whole area
        .onTapGesture(count: 1, perform: {
          // cancel any previous edit
          self.con.dispatcher.sendSignal(signal: .CANCEL_OTHER_EDIT_ROOT, senderID: con.treeID)
          // switch to Editing mode
          self.swiftTreeState.isEditingRoot = true
        })

      } // editing / not editing

    }  // HStack
  }

}

struct RootDirPanel_Previews: PreviewProvider {
  static var previews: some View {
    RootDirPanel(controller: MockTreeController(ID_LEFT_TREE), canChangeRoot: true)
  }
}

