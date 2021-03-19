//
//  TernaryToggleButton.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-13.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

typealias NoArgVoidFunc = () -> Void

struct SelectedToolIcon: View {
  let img: ImageProvider

  init(_ img: ImageProvider) {
    self.img = img
  }

  var body: some View {
    ZStack {

      Circle().fill(Color.white)
        .frame(width: self.img.width, height: self.img.height)
        .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)

      self.img.getImage()
        .colorInvert()
        .clipShape(Circle())
        .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)
        .accentColor(.white)

    }
  }
}

struct UnselectedToolIcon: View {
  let img: ImageProvider

  init(_ img: ImageProvider) {
    self.img = img
  }

  var body: some View {
    self.img.getImage()
      .accentColor(.black)
  }
}

/**
 STRUCT TernaryToggleButton
 */
struct TernaryToggleButton: View {
  let iconStore: IconStore
  let iconTrue: IconId
  let iconFalse: IconId
  let iconNotSpecified: IconId
  @Binding var isEnabled: Ternary
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ iconStore: IconStore, iconTrue: IconId, iconFalse: IconId, iconNotSpecified: IconId? = nil,
       _ isEnabled: Binding<Ternary>, onClickAction: NoArgVoidFunc? = nil) {
    self.iconStore = iconStore
    self.iconTrue = iconTrue
    self.iconFalse = iconFalse
    self.iconNotSpecified = iconNotSpecified == nil ? self.iconTrue : iconNotSpecified!
    self._isEnabled = isEnabled
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
    NSLog("DEBUG Toggled button ternary value to \(isEnabled)")
  }

  var body: some View {
    Button(action: onClickAction!) {

      switch isEnabled {
        case .TRUE:
          SelectedToolIcon(self.iconStore.getIcon(for: self.iconTrue))
        case .FALSE:
          SelectedToolIcon(self.iconStore.getIcon(for: self.iconFalse))
        case .NOT_SPECIFIED:
          UnselectedToolIcon(self.iconStore.getIcon(for: self.iconNotSpecified))
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

/**
 STRUCT BoolToggleButton
 */
struct BoolToggleButton: View {
  let iconStore: IconStore
  let iconTrue: IconId
  let iconFalse: IconId
  @Binding var isEnabled: Bool
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ iconStore: IconStore, iconTrue: IconId, iconFalse: IconId? = nil,
       _ isEnabled: Binding<Bool>, onClickAction: NoArgVoidFunc? = nil, font: Font = DEFAULT_FONT) {
    self.iconStore = iconStore
    self.iconTrue = iconTrue
    self.iconFalse = iconFalse == nil ? iconTrue : iconFalse!
    self._isEnabled = isEnabled
    self.onClickAction = onClickAction == nil ? self.toggleValue : onClickAction!
  }

  private func toggleValue() {
    isEnabled.toggle()
    NSLog("DEBUG Toggled button bool value to \(isEnabled)")
  }

  var body: some View {
    Button(action: onClickAction!) {
      if isEnabled {
        SelectedToolIcon(self.iconStore.getIcon(for: self.iconTrue))
      } else {
        UnselectedToolIcon(self.iconStore.getIcon(for: self.iconFalse))
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}


struct TernaryToggleButton_Previews: PreviewProvider {
  static let backend = MockBackend(SignalDispatcher())
  static let iconStore = IconStore(backend)
  static var previews: some View {
    HStack {
      TernaryToggleButton(iconStore, iconTrue: .ICON_IS_SHARED, iconFalse: .ICON_IS_NOT_SHARED, .constant(Ternary.TRUE))
      TernaryToggleButton(iconStore, iconTrue: .ICON_IS_TRASHED, iconFalse: .ICON_IS_NOT_TRASHED, .constant(Ternary.TRUE))
      TernaryToggleButton(iconStore, iconTrue: .ICON_IS_SHARED, iconFalse: .ICON_IS_NOT_TRASHED, .constant(Ternary.TRUE))
    }
  }
}
