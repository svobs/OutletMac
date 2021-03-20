//
//  TernaryToggleButton.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-13.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

let ICON_PADDING: CGFloat = 8

typealias NoArgVoidFunc = () -> Void

fileprivate struct SelectedToolbarIcon: View {
  let img: ImageProvider

  init(_ img: ImageProvider) {
    self.img = img
  }

  var body: some View {
    ZStack {

      Circle().fill(Color.white)
        .frame(width: self.img.width + ICON_PADDING, height: self.img.height + ICON_PADDING)
        .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)

      self.img.getImage()
        .if(self.img.isGrayscale) { $0.colorInvert() }
        .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)
        .accentColor(.white)
        .frame(width: self.img.width + ICON_PADDING, height: self.img.height + ICON_PADDING, alignment: .center)
    }
  }
}

struct UnselectedToolbarIcon: View {
  let img: ImageProvider

  init(_ img: ImageProvider) {
    self.img = img
  }

  var body: some View {
    self.img.getImage()
      .accentColor(.black)
      .frame(width: self.img.width + ICON_PADDING, height: self.img.height + ICON_PADDING, alignment: .center)
  }
}

/**
 STRUCT TernaryToggleButton
 */
struct TernaryToggleButton: View {
  let iconStore: IconStore
  let iconTrue: IconID
  let iconFalse: IconID
  let iconNotSpecified: IconID
  @Binding var isEnabled: Ternary
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ iconStore: IconStore, iconTrue: IconID, iconFalse: IconID, iconNotSpecified: IconID? = nil,
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
          SelectedToolbarIcon(self.iconStore.getIcon(for: self.iconTrue))
        case .FALSE:
          SelectedToolbarIcon(self.iconStore.getIcon(for: self.iconFalse))
        case .NOT_SPECIFIED:
          UnselectedToolbarIcon(self.iconStore.getIcon(for: self.iconNotSpecified))
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
  let iconTrue: IconID
  let iconFalse: IconID
  @Binding var isEnabled: Bool
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ iconStore: IconStore, iconTrue: IconID, iconFalse: IconID? = nil,
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
        SelectedToolbarIcon(self.iconStore.getIcon(for: self.iconTrue))
      } else {
        UnselectedToolbarIcon(self.iconStore.getIcon(for: self.iconFalse))
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

/**
 CLASS PlayPauseToggleButton
 */
struct PlayPauseToggleButton: View {
  @Binding var isPlaying: Bool
  let iconStore: IconStore
  let dispatcher: SignalDispatcher
  private var onClickAction: NoArgVoidFunc? = nil

  init(_ iconStore: IconStore, _ isPlaying: Binding<Bool>, _ dispatcher: SignalDispatcher) {
    self.iconStore = iconStore
    self._isPlaying = isPlaying
    self.dispatcher = dispatcher
    self.onClickAction = onClickAction == nil ? self.toggleValue : onClickAction!
  }

  private func toggleValue() {
    if self.isPlaying {
      NSLog("Play/Pause btn clicked! Sending signal \(Signal.PAUSE_OP_EXECUTION)")
      dispatcher.sendSignal(signal: .PAUSE_OP_EXECUTION, senderID: ID_MAIN_WINDOW)
    } else {
      NSLog("Play/Pause btn clicked! Sending signal \(Signal.RESUME_OP_EXECUTION)")
      dispatcher.sendSignal(signal: .RESUME_OP_EXECUTION, senderID: ID_MAIN_WINDOW)
    }
  }

  var body: some View {
    Button(action: onClickAction!) {
      if isPlaying {
        UnselectedToolbarIcon(iconStore.getIcon(for: .ICON_PAUSE))
      } else {
        SelectedToolbarIcon(iconStore.getIcon(for: .ICON_PLAY))
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
