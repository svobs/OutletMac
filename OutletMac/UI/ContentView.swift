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
  let backend: OutletBackend
  let conLeft: TreeControllable
  let conRight: TreeControllable
  let items: [ExampleClass] = exampleArray()

  init(backend: OutletBackend, conLeft: TreeControllable, conRight: TreeControllable) {
    self.backend = backend
    self.conLeft = conLeft
    self.conRight = conRight
  }

  var body: some View {
    TwoPaneView(backend: backend, conLeft: self.conLeft, conRight: self.conRight)
    //        SplitView(items: items)
  }
}


@available(OSX 11.0, *)
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(backend: NullBackend(), conLeft: NullTreeController(ID_LEFT_TREE), conRight: NullTreeController(ID_RIGHT_TREE))
  }
}

