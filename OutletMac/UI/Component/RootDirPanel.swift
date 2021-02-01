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
  var isEditing: Bool
  var canChangeRoot: Bool
  var isRootExists: Bool = false
  @State var rootPath: String = "/usr/path"

  init(canChangeRoot: Bool, isEditing: Bool) {
    self.canChangeRoot = canChangeRoot
    self.isEditing = isEditing
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
        TextField("Enter path...", text: $rootPath)
      } else {
        Text(rootPath)
      }
    }
  }
}

@available(OSX 11.0, *)
struct RootDirPanel_Previews: PreviewProvider {
  static var previews: some View {
    RootDirPanel(canChangeRoot: true, isEditing: true)
  }
}
