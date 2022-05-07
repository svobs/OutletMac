//
//  TernaryToggleButton.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-13.
//

import SwiftUI
import OutletCommon

// TODO: add glow on hover
fileprivate struct SelectedToolbarIcon: View {
  let img: ImageContainer

  init(_ img: ImageContainer) {
    self.img = img
  }

  var body: some View {
    ZStack {

      Circle().fill(Color.white)
        .frame(width: self.img.width + ICON_PADDING, height: self.img.height + ICON_PADDING)
        .shadow(color: .white, radius: BUTTON_SHADOW_RADIUS)

      self.img.getImage()
        .if(self.img.isGrayscale) { $0.colorInvert() }
        .frame(width: self.img.width + ICON_PADDING, height: self.img.height + ICON_PADDING, alignment: .center)
    }
  }
}

fileprivate struct UnselectedToolbarIcon: View {
  let img: ImageContainer

  init(_ img: ImageContainer) {
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
          SelectedToolbarIcon(self.iconStore.getToolbarIcon(for: self.iconTrue))
        case .FALSE:
          SelectedToolbarIcon(self.iconStore.getToolbarIcon(for: self.iconFalse))
        case .NOT_SPECIFIED:
          UnselectedToolbarIcon(self.iconStore.getToolbarIcon(for: self.iconNotSpecified))
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
        SelectedToolbarIcon(self.iconStore.getToolbarIcon(for: self.iconTrue))
      } else {
        UnselectedToolbarIcon(self.iconStore.getToolbarIcon(for: self.iconFalse))
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

/**
 CLASS PlayPauseToggleButton
 */
struct PlayPauseToggleButton: View {
  @EnvironmentObject var globalState: GlobalState
  let iconStore: IconStore
  let dispatcher: SignalDispatcher

  let iconPause: ImageContainer
  let iconPlay: ImageContainer

  init(_ iconStore: IconStore, _ dispatcher: SignalDispatcher) {
    self.iconStore = iconStore
    self.dispatcher = dispatcher
    self.iconPause = iconStore.getToolbarIcon(for: .ICON_PAUSE)
    self.iconPlay = iconStore.getToolbarIcon(for: .ICON_PLAY)
  }

  private func toggleValue() {
    if self.globalState.isBackendOpExecutorRunning {
      NSLog("INFO  Play/Pause btn clicked! Sending signal \(Signal.PAUSE_OP_EXECUTION)")
      dispatcher.sendSignal(signal: .PAUSE_OP_EXECUTION, senderID: ID_MAIN_WINDOW)
    } else {
      NSLog("INFO  Play/Pause btn clicked! Sending signal \(Signal.RESUME_OP_EXECUTION)")
      dispatcher.sendSignal(signal: .RESUME_OP_EXECUTION, senderID: ID_MAIN_WINDOW)
    }
  }

  var body: some View {
    Button(action: toggleValue) {
      if globalState.isBackendOpExecutorRunning {
        UnselectedToolbarIcon(self.iconPause)
      } else {
        UnselectedToolbarIcon(self.iconPlay)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}
