//
//  ContentView.swift
//  OutlineView
//
//  Created by Toph Allen on 4/13/20.
//  Copyright © 2020 Toph Allen. All rights reserved.
//

import SwiftUI


struct ContentView: View {
  @EnvironmentObject var settings: GlobalSettings
  let app: OutletApp
  let conLeft: TreeControllable
  let conRight: TreeControllable
  @State private var window: NSWindow?  // enclosing window(?)

  init(app: OutletApp, conLeft: TreeControllable, conRight: TreeControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
  }

  var body: some View {
    let tapCancelEdit = TapGesture()
      .onEnded { _ in
        NSLog("Tapped!")
        app.dispatcher.sendSignal(signal: .CANCEL_ALL_EDIT_ROOT, senderID: ID_MAIN_WINDOW)
      }

    TwoPaneView(app: self.app, conLeft: self.conLeft, conRight: self.conRight)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .contentShape(Rectangle()) // taps should be detected in the whole window
      .gesture(tapCancelEdit)
      .alert(isPresented: $settings.showingAlert) {
        Alert(title: Text(settings.alertTitle), message: Text(settings.alertMsg), dismissButton: .default(Text(settings.dismissButtonText)))
      }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(app: MockApp(), conLeft: MockTreeController(ID_LEFT_TREE), conRight: MockTreeController(ID_RIGHT_TREE))
      .environmentObject(GlobalSettings())
  }
}

