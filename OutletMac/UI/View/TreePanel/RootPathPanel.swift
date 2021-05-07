//
//  RootPathPanel.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-31.
//
import SwiftUI

/**
 STRUCT RootPathPanel
 */
struct RootPathPanel: View {
  @ObservedObject var swiftTreeState: SwiftTreeState
  let con: TreePanelControllable

  private let colors: [Color] = [.gray, .red, .orange, .yellow, .green, .blue, .purple, .pink]
  @State private var fgColor: Color = .gray

  init(_ controller: TreePanelControllable) {
    self.con = controller
    self.swiftTreeState = self.con.swiftTreeState
  }

  func submitRootPath() {
    do {
      _ = try self.con.backend.createDisplayTreeFromUserPath(treeID: self.con.tree.treeID, userPath: self.swiftTreeState.rootPath, deviceUID: self.swiftTreeState.rootDeviceUID)
    } catch {
      NSLog("Failed to submit root path \"\(self.swiftTreeState.rootPath)\": \(error)")
      // restore root path to value received from server
      self.swiftTreeState.rootPath = self.con.tree.rootPath
    }
  }

  private func getIconForTreeType(_ treeType: TreeType) -> Image {
    var iconId: IconID

    switch treeType {
      case .GDRIVE:
        iconId = .BTN_GDRIVE
      case .LOCAL_DISK:

        // FIXME: need way to distinguish between OSes

        iconId = .BTN_LOCAL_DISK_MACOS
      case .MIXED, .NA:
        iconId = .BTN_FOLDER_TREE
    }
    return con.app.iconStore.getIcon(for: iconId).getImage()
  }

  // TODO: this is TEMPORARY until we support multiple drives
  func getDefaultLocalDeviceUID() throws -> UID {
    var deviceUID: UID? = nil
    for device in try self.con.backend.getDeviceList() {
      if device.treeType == .LOCAL_DISK {
        if deviceUID != nil {
          throw OutletError.invalidState("Multiple local disks found but this is not supported!")
        } else {
          deviceUID = device.uid
        }
      }
    }
    if deviceUID == nil {
      throw OutletError.invalidState("No local disks found!")
    } else {
      return deviceUID!
    }
  }

  func doOpenFileDialog() {
    let deviceUID: UID
    do {
      deviceUID = try self.getDefaultLocalDeviceUID()
    } catch {
      self.con.reportError("Failed to open file dialog", "\(error)")
      return
    }

    let dialog = NSOpenPanel();

    dialog.title                   = "Choose a directory";  // Not shown in Mac OS Big Bug
    if self.con.tree.treeType == .LOCAL_DISK {
      // Open to current directory by default (if available):
      // TODO: only do this for this machine (need to check this somehow)
      dialog.directoryURL = URL(fileURLWithPath: self.con.tree.rootPath)
    }
    dialog.showsResizeIndicator    = true;
    dialog.showsHiddenFiles        = false;
    dialog.canChooseFiles          = false;
    dialog.canChooseDirectories    = true;
    dialog.canCreateDirectories    = true;
    dialog.allowsMultipleSelection = false;

    if (dialog.runModal() == .OK) {
      let result = dialog.url // Pathname of the file

      if (result != nil) {
        let dirPath = result!.path
        NSLog("INFO  User chose path: \(dirPath)")
        do {
          let _ = try self.con.backend.createDisplayTreeFromUserPath(treeID: self.con.treeID, userPath: dirPath, deviceUID: deviceUID)
        } catch {
          self.con.reportError("Failed to set tree root path", "Failed to set path (\(dirPath)): \(error)")
        }
      }
    } else {
      NSLog("DEBUG User cancelled Open File dialog")
      return
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: H_PAD) {

      Button(action: {
      }) {
        self.getIconForTreeType(swiftTreeState.treeType)
          .padding(.leading, H_PAD)
      }
      .contextMenu {
        Button("Local filesystem subtree...", action: self.doOpenFileDialog)
        Button("Google Drive subtree...", action: {
                NSApp.sendAction(#selector(OutletMacApp.openGDriveRootChooser), to: nil, from:self.con.treeID)})
      }
      .buttonStyle(PlainButtonStyle())

      if !self.swiftTreeState.isRootExists {
        con.app.iconStore.getIcon(for: .ICON_ALERT).getImage()
          .foregroundColor(.yellow)  // in case we are using system image (font)
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
        .font(ROOT_PATH_ENTRY_FONT)
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
              .font(ROOT_PATH_ENTRY_FONT)
          } else {
            Text(self.swiftTreeState.rootPathNonEdit)
              .multilineTextAlignment(.leading)
              .font(ROOT_PATH_ENTRY_FONT)
              .foregroundColor(self.swiftTreeState.isRootExists ? .primary : .red)
          }
          Spacer() // this will align the preceding Text object to the left
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle()) // taps should be detected in the whole area
        .onTapGesture(count: 1, perform: {
          // cancel any previous edit
          self.con.dispatcher.sendSignal(signal: .CANCEL_OTHER_EDIT_ROOT, senderID: con.treeID)
          // switch to Editing mode if allowed
          if self.con.canChangeRoot {
            self.swiftTreeState.isEditingRoot = true
          }
        })

      } // editing / not editing

    }  // HStack
    .frame(minWidth: 300,
           maxWidth: .infinity,
           alignment: .topLeading)
    .padding(.top, V_PAD)

//    .background(Color.blue)  // TODO
  }

}

struct RootPathPanel_Previews: PreviewProvider {
  static var previews: some View {
    RootPathPanel(try! MockTreePanelController(ID_LEFT_TREE, canChangeRoot: true))
  }
}

