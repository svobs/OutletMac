//
//  MainContentView.swift
//
//  Created by Matthew Svoboda on 1/6/21.
//

import SwiftUI


// Main window content view
struct MainContentView: View {
  @EnvironmentObject var globalState: GlobalState
  @StateObject var windowState: WindowState = WindowState()
  weak var app: OutletApp!
  weak var conLeft: TreePanelControllable!
  weak var conRight: TreePanelControllable!
  @State private var window: NSWindow?  // enclosing window(?)

  init(app: OutletApp, conLeft: TreePanelControllable, conRight: TreePanelControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
  }

  func dismissAlert() {
     DispatchQueue.main.async {
       self.globalState.dismissAlert()
     }
  }

  var body: some View {
    let tapCancelEdit = TapGesture()
      .onEnded { _ in
        NSLog("DEBUG Tapped!")
        app.dispatcher.sendSignal(signal: .CANCEL_ALL_EDIT_ROOT, senderID: ID_MAIN_WINDOW)
      }

    // Here, I use GeometryReader to get the full canvas size (sans window decoration)
    GeometryReader { geo in
      TwoPaneView(app: self.app, conLeft: self.conLeft, conRight: self.conRight, windowState)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle()) // taps should be detected in the whole window
        .gesture(tapCancelEdit)
        .alert(isPresented: $globalState.showingAlert) {
          Alert(title: Text(globalState.alertTitle),
                message: Text(globalState.alertMsg),
                dismissButton: .default(Text(globalState.dismissButtonText), action: self.dismissAlert))
        }
        .preference(key: ContentAreaPrefKey.self, value: ContentAreaPrefData(height: geo.size.height))
      .onPreferenceChange(ContentAreaPrefKey.self) { key in
//        NSLog("HEIGHT OF WINDOW CANVAS: \(key.height)")
        self.windowState.windowHeight = key.height
      }
    }
  }
}
