//
//  MainContentView.swift
//
//  Created by Matthew Svoboda on 1/6/21.
//

import SwiftUI


// Main window content view
struct MainContentView: View {
  @EnvironmentObject var settings: GlobalSettings
  @StateObject var heightTracking: HeightTracking = HeightTracking()
  weak var app: OutletApp!
  weak var conLeft: TreePanelControllable!
  weak var conRight: TreePanelControllable!
  @State private var window: NSWindow?  // enclosing window(?)

  init(app: OutletApp, conLeft: TreePanelControllable, conRight: TreePanelControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
  }

  var body: some View {
    let tapCancelEdit = TapGesture()
      .onEnded { _ in
        NSLog("DEBUG Tapped!")
        app.dispatcher.sendSignal(signal: .CANCEL_ALL_EDIT_ROOT, senderID: ID_MAIN_WINDOW)
      }

    // Here, I use GeometryReader to get the full canvas size (sans window decoration)
    GeometryReader { geo in
      TwoPaneView(app: self.app, conLeft: self.conLeft, conRight: self.conRight, heightTracking)
        .environmentObject(settings)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle()) // taps should be detected in the whole window
        .gesture(tapCancelEdit)
        .alert(isPresented: $settings.showingAlert) {
          Alert(title: Text(settings.alertTitle), message: Text(settings.alertMsg), dismissButton: .default(Text(settings.dismissButtonText)))
        }
        .preference(key: ContentAreaPrefKey.self, value: ContentAreaPrefData(height: geo.size.height))
      .onPreferenceChange(ContentAreaPrefKey.self) { key in
//        NSLog("HEIGHT OF WINDOW CANVAS: \(key.height)")
        self.heightTracking.mainWindowHeight = key.height
      }
    }
  }
}

struct MainContentView_Previews: PreviewProvider {
  static var previews: some View {
    MainContentView(app: MockApp(), conLeft: try! MockTreePanelController(ID_LEFT_TREE, canChangeRoot: true), conRight: try! MockTreePanelController(ID_RIGHT_TREE, canChangeRoot: true))
      .environmentObject(GlobalSettings())
  }
}
