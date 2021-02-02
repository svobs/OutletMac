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
    TwoPaneView(app: self.app, conLeft: self.conLeft, conRight: self.conRight)
    //        SplitView(items: items)
  }
}


@available(OSX 11.0, *)
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(app: MockApp(), conLeft: MockTreeController(ID_LEFT_TREE), conRight: MockTreeController(ID_RIGHT_TREE))
  }
}

