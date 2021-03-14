//
//  TernaryToggleButton.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-13.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

typealias NoArgVoidFunc = () -> Void


struct InvertedWhiteCircleImage: View {
  let imageName: String?
  let systemImageName: String?
  let width: CGFloat
  let height: CGFloat
  let font: Font

  init(imageName: String? = nil, systemImageName: String? = nil, width: CGFloat, height: CGFloat, font: Font = DEFAULT_FONT) {
    self.imageName = imageName
    self.systemImageName = systemImageName
    self.width = width
    self.height = height
    self.font = font
  }

  var body: some View {
    ZStack {

      Circle().fill(Color.white)
        .frame(width: self.width, height: self.height)
        .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)

      if systemImageName != nil {
        Image(systemName: self.systemImageName!)
          .renderingMode(.template)
          .colorInvert()
          .frame(width: self.width, height: self.height)
          .font(self.font)
          .clipShape(Circle())
          .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)
          .accentColor(.white)
      } else {
        Image(self.imageName!)
          .renderingMode(.template)
          .colorInvert()
          .frame(width: self.width, height: self.height)
          .font(self.font)
          .clipShape(Circle())
          .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)
          .accentColor(.white)
      }

    }
  }
}

struct RegularImage: View {
  let imageName: String?
  let systemImageName: String?
  let width: CGFloat
  let height: CGFloat
  let font: Font

  init(imageName: String? = nil, systemImageName: String? = nil, width: CGFloat, height: CGFloat, font: Font = DEFAULT_FONT) {
    self.imageName = imageName
    self.systemImageName = systemImageName
    self.width = width
    self.height = height
    self.font = font
  }

  var body: some View {

    if self.systemImageName != nil {
      Image(systemName: self.systemImageName!)
        .renderingMode(.template)
        .frame(width: width, height: height)
        .font(self.font)
        .accentColor(.black)
    } else {
      Image(self.imageName!)
        .renderingMode(.template)
        .frame(width: width, height: height)
        .font(self.font)
        .accentColor(.black)
    }
  }
}

/**
 STRUCT TernaryToggleButton
 */
struct TernaryToggleButton: View {
  @Binding var isEnabled: Ternary
  /** Reminder: can use the "SF Symbols" app to browse for an appropriate image */
  let imageName: String?
  let systemImageName: String?
  let width: CGFloat
  let height: CGFloat
  let font: Font
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ isEnabled: Binding<Ternary>, imageName: String? = nil, systemImageName: String? = nil, width: CGFloat? = nil, height: CGFloat? = nil, onClickAction: NoArgVoidFunc? = nil, font: Font = DEFAULT_FONT) {
    self._isEnabled = isEnabled
    assert(!(imageName == nil && systemImageName == nil), "imageName and systemImageName cannot both be nil")
    assert(!(imageName != nil && systemImageName != nil), "imageName and systemImageName cannot both be specified")
    self.imageName = imageName
    self.systemImageName = systemImageName
    self.width = width == nil ? DEFAULT_TERNARY_BTN_WIDTH : width!
    self.height = height == nil ? DEFAULT_TERNARY_BTN_HEIGHT : height!
    self.font = font
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

      switch isEnabled {
        case .TRUE:
          InvertedWhiteCircleImage(imageName: imageName, systemImageName: systemImageName, width: width, height: height, font: font)
        case .FALSE:
          // TODO: disable icon
          RegularImage(imageName: imageName, systemImageName: systemImageName, width: width, height: height, font: font)
        case .NOT_SPECIFIED:
          RegularImage(imageName: imageName, systemImageName: systemImageName, width: width, height: height, font: font)
      }

    }
    .buttonStyle(PlainButtonStyle())
  }
}

extension TernaryToggleButton {
  public func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> TernaryToggleButton {
    return TernaryToggleButton(self._isEnabled, imageName: self.imageName, width: width, height: height, font: font)
  }
}

/**
 STRUCT BoolToggleButton

 TODO: refactor to share code with TernaryToggleButton
 */
struct BoolToggleButton: View {
  @Binding var isEnabled: Bool
  let imageName: String?
  let systemImageName: String?
  let width: CGFloat
  let height: CGFloat
  let font: Font
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ isEnabled: Binding<Bool>, imageName: String? = nil, systemImageName: String? = nil, width: CGFloat? = nil, height: CGFloat? = nil, onClickAction: NoArgVoidFunc? = nil, font: Font = DEFAULT_FONT) {
    self._isEnabled = isEnabled
    assert(!(imageName == nil && systemImageName == nil), "imageName and systemImageName cannot both be nil")
    assert(!(imageName != nil && systemImageName != nil), "imageName and systemImageName cannot both be specified")
    self.imageName = imageName
    self.systemImageName = systemImageName
    self.width = width == nil ? DEFAULT_TERNARY_BTN_WIDTH : width!
    self.height = height == nil ? DEFAULT_TERNARY_BTN_HEIGHT : height!
    self.font = font
    self.onClickAction = onClickAction == nil ? self.toggleValue : onClickAction!
  }

  private func toggleValue() {
    isEnabled.toggle()
    NSLog("Toggled button bool value to \(isEnabled)")
  }

  var body: some View {
    Button(action: onClickAction!) {
      if isEnabled {
        InvertedWhiteCircleImage(imageName: imageName, systemImageName: systemImageName, width: width, height: height, font: font)
      } else {
        // TODO: disable icon
        RegularImage(imageName: imageName, systemImageName: systemImageName, width: width, height: height, font: font)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}


struct TernaryToggleButton_Previews: PreviewProvider {
  static var previews: some View {
    HStack {
      TernaryToggleButton(.constant(Ternary.TRUE), systemImageName: "person.2.fill")
      TernaryToggleButton(.constant(Ternary.FALSE), systemImageName: "trash")
      TernaryToggleButton(.constant(Ternary.NOT_SPECIFIED), systemImageName: "trash")
    }
  }
}
