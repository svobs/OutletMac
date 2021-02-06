//
//  ContentView.swift
//  OutlineView
//
//  Created by Toph Allen on 4/13/20.
//  Copyright © 2020 Toph Allen. All rights reserved.
//

import SwiftUI


@available(OSX 11.0, *)
struct ContentView: View {
  let app: OutletApp
  let conLeft: TreeControllable
  let conRight: TreeControllable
  let items: [ExampleClass] = exampleArray()

  init(app: OutletApp, conLeft: TreeControllable, conRight: TreeControllable) {
    self.app = app
    self.conLeft = conLeft
    self.conRight = conRight
  }

  var body: some View {
    ZStack {
      TwoPaneView(app: self.app, conLeft: self.conLeft, conRight: self.conRight)
        .contentShape(Rectangle()) // taps should be detected in the whole window
        .simultaneousGesture(
          // TODO: this *almost* gets us what we want. This will work for all Views inside our window except
          // for the ones which have a TapGesture handler already assigned
          TapGesture().onEnded { _ in
            NSLog("Tapped!")
            app.dispatcher.sendSignal(signal: .END_EDITING, senderID: ID_MAIN_WINDOW)
          }
        )
    }
  }
}

@available(OSX 11.0, *)
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(app: MockApp(), conLeft: MockTreeController(ID_LEFT_TREE), conRight: MockTreeController(ID_RIGHT_TREE))
  }
}

