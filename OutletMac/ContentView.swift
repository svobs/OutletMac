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
    let items: [ExampleClass] = exampleArray()
    
    var body: some View {
        TwoPaneView()
//        SplitView(items: items)
    }
}


@available(OSX 11.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

