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

typealias NoArgVoidFunc = () -> Void

/**
 STRUCT TernaryToggleButton
 */
struct TernaryToggleButton: View {
  @Binding var isEnabled: Ternary
  /** Reminder: can use the "SF Symbols" app to browse for an appropriate image */
  let imageName: String
  let width: CGFloat
  let height: CGFloat
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ isEnabled: Binding<Ternary>, imageName: String, width: CGFloat? = nil, height: CGFloat? = nil, onClickAction: NoArgVoidFunc? = nil) {
    self._isEnabled = isEnabled
    self.imageName = imageName
    self.width = width == nil ? DEFAULT_TERNARY_BTN_WIDTH : width!
    self.height = height == nil ? DEFAULT_TERNARY_BTN_HEIGHT : height!
    self.onClickAction = onClickAction == nil ? self.toggleValue : onClickAction!
  }

  // default behavior: toggle through all possible values
  private func toggleValue() {
    switch isEnabled {
      case .TRUE:
        isEnabled = .FALSE
      case .FALSE:
        isEnabled = .NOT_SPECIFIED
      case .NOT_SPECIFIED:
        isEnabled = .TRUE
    }
    NSLog("Toggled button ternary value to \(isEnabled)")
  }

  var body: some View {
    Button(action: onClickAction!) {
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
      //      .overlay(
      //        RoundedRectangle(cornerRadius: 10.0)
      //          .stroke(lineWidth: 2.0)
      //      )

    }
    .buttonStyle(PlainButtonStyle())
  }
}

extension TernaryToggleButton {
  public func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> TernaryToggleButton {
    return TernaryToggleButton(self._isEnabled, imageName: self.imageName, width: width, height: height)
  }
}

/**
 STRUCT BoolToggleButton

 TODO: refactor to share code with TernaryToggleButton
 */
struct BoolToggleButton: View {
  @Binding var isEnabled: Bool
  let imageName: String
  let width: CGFloat
  let height: CGFloat
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ isEnabled: Binding<Bool>, imageName: String, width: CGFloat? = nil, height: CGFloat? = nil, onClickAction: NoArgVoidFunc? = nil) {
    self._isEnabled = isEnabled
    self.imageName = imageName
    self.width = width == nil ? DEFAULT_TERNARY_BTN_WIDTH : width!
    self.height = height == nil ? DEFAULT_TERNARY_BTN_HEIGHT : height!
    self.onClickAction = onClickAction == nil ? self.toggleValue : onClickAction!
  }

  private func toggleValue() {
    isEnabled.toggle()
    NSLog("Toggled button bool value to \(isEnabled)")
  }

  var body: some View {
    Button(action: onClickAction!) {
      ZStack {

        if isEnabled {

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
            .accentColor(isEnabled ? .white : .black)

        } else {

          Image(systemName: self.imageName)
            .renderingMode(.template)
            .frame(width: width, height: height)
            .font(Font.system(.title))
//            .clipShape(RoundedRectangle(cornerRadius: 10.0))

            .accentColor(isEnabled ? .white : .black)
//            .overlay(Circle().stroke(Color.red, lineWidth: 2))

        }
      }
//      .overlay(
//        RoundedRectangle(cornerRadius: 10.0)
//          .stroke(lineWidth: 2.0)
//      )

    }
    .buttonStyle(PlainButtonStyle())
  }
}


struct TernaryToggleButton_Previews: PreviewProvider {
  static var previews: some View {
    HStack {
      TernaryToggleButton(.constant(Ternary.TRUE), imageName: "person.2.fill")
      TernaryToggleButton(.constant(Ternary.FALSE), imageName: "trash")
      TernaryToggleButton(.constant(Ternary.NOT_SPECIFIED), imageName: "trash")
    }
  }
}
