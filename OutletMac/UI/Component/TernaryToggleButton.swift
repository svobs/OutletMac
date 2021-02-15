//
//  TernaryToggleButton.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-13.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

let DEFAULT_TERNARY_BTN_WIDTH: CGFloat = 32
let DEFAULT_TERNARY_BTN_HEIGHT: CGFloat = 32

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

    Button(action: {
      print("Button action")
    }) {
      ZStack {

        if isEnabled == .TRUE {

          Circle().fill(Color.white)
            .frame(width: width, height: height)
            .shadow(color: .white, radius: 3.0)

          Image(systemName: self.imageName)
            .renderingMode(.template)
            .colorInvert()
            .frame(width: width, height: height)
            .font(Font.system(.title))
            .clipShape(Circle())
            .shadow(color: .white, radius: 3.0)
            .accentColor(isEnabled == .TRUE ? .white : .black)

        } else {

          Image(systemName: self.imageName)
            .renderingMode(.template)
            .frame(width: width, height: height)
            .font(Font.system(.title))
//            .clipShape(RoundedRectangle(cornerRadius: 10.0))

            .accentColor(isEnabled == .TRUE ? .white : .black)
//            .overlay(Circle().stroke(Color.red, lineWidth: 2))

        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 10.0)
          .stroke(lineWidth: 2.0)
      )

    }
    .buttonStyle(PlainButtonStyle())
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
