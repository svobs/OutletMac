//
//  TernaryToggleButton.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-13.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

let DEFAULT_TERNARY_BTN_WIDTH: CGFloat = 40
let DEFAULT_TERNARY_BTN_HEIGHT: CGFloat = 40

let DEFAULT_TERNARY_ICON_WIDTH: CGFloat = 32
let DEFAULT_TERNARY_ICON_HEIGHT: CGFloat = 32

/**
 STRUCT TernaryToggleButton
 */
struct TernaryToggleButton: View {
  let isEnabled: Ternary
  let imageName: String
  let width: CGFloat
  let height: CGFloat

  init(_ isEnabled: Ternary, imageName: String, width: CGFloat? = nil, height: CGFloat? = nil) {
    self.isEnabled = isEnabled
    self.imageName = imageName
    self.width = width == nil ? DEFAULT_TERNARY_BTN_WIDTH : width!
    self.height = height == nil ? DEFAULT_TERNARY_BTN_HEIGHT : height!
  }

  var body: some View {
    ZStack {

      if isEnabled == .TRUE {
        Circle().fill(Color.white)
          .frame(width: DEFAULT_TERNARY_ICON_WIDTH, height: DEFAULT_TERNARY_ICON_HEIGHT)

        Image(systemName: self.imageName)
          .renderingMode(.template)
          .colorInvert()
          .frame(width: width, height: height)
          .font(Font.system(.title))
          .clipShape(Circle())

          .accentColor(isEnabled == .TRUE ? .white : .black)
//          .shadow(radius: 2)
      } else {
        Image(systemName: self.imageName)
          .renderingMode(.template)
          .frame(width: width, height: height)
          .font(Font.system(.title))
          .clipShape(Circle())

          .accentColor(isEnabled == .TRUE ? .white : .black)
//          .shadow(radius: 5)
        //        .overlay(Circle().stroke(Color.red, lineWidth: 2))
      }

    }
  }
}

extension TernaryToggleButton {
  public func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> TernaryToggleButton {
    return TernaryToggleButton(self.isEnabled, imageName: self.imageName, width: width, height: height)
  }
}

struct TernaryToggleButton_Previews: PreviewProvider {
  static var previews: some View {
    TernaryToggleButton(.TRUE, imageName: "trash")
  }
}
