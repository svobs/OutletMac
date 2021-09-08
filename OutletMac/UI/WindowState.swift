//
// Created by Matthew Svoboda on 21/9/7.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

class WindowState: ObservableObject {
    // These two values are calculated and stored so that the proper height of the OutlineView can be derived
    @Published var windowHeight: CGFloat = 0
    @Published var nonTreeViewHeight: CGFloat = 0

    func getTreeViewHeight() -> CGFloat {
//    NSLog("DEBUG getTreeViewHeight(): \(self.windowHeight) - \(self.nonTreeViewHeight)")
        return self.windowHeight - self.nonTreeViewHeight
    }

}


struct MyHeightPreferenceData: Equatable {
    var col0: [String: CGFloat] = [:]
    var col1: [String: CGFloat] = [:]

    init(name: String, col: UInt, height: CGFloat) {
        if col == 0 {
            col0[name] = height
        } else if col == 1 {
            col1[name] = height
        }
    }

    init() {
    }
}


struct MyHeightPreferenceKey: PreferenceKey {
    /**
     Value: is a typealias that indicates what type of information we want to expose through the preference.
     In this example you see that we are using an array of MyHeightPreferenceData. I will get to that in a minute.
     */
    typealias Value = MyHeightPreferenceData

    /**
     When a preference key value has not been set explicitly, SwiftUI will use this defaultValue.
     */
    static var defaultValue: MyHeightPreferenceData = MyHeightPreferenceData()

    /**
     reduce: This is a static function that SwiftUI will use to merge all the key values found in the view tree. Normally, you use it to accumulate all the values it receives, but you can do whatever you want. In our case, when SwiftUI goes through the tree, it will collect the preference key values and store them together in a single array, which we will be able to access later. You should know that Values are supplied to the reduce function in view-tree order. We’ll come back to that in another example, as the order is not relevant here.
     */
    static func reduce(value: inout MyHeightPreferenceData, nextValue: () -> MyHeightPreferenceData) {
        let next = nextValue()
        for (name, size) in next.col0 {
            value.col0[name] = size
        }
        for (name, size) in next.col1 {
            value.col1[name] = size
        }
//    NSLog("REDUCE: \(value.col0), \(value.col1)")
    }
}


struct ContentAreaPrefData: Equatable {
    var height: CGFloat
}


struct ContentAreaPrefKey: PreferenceKey {
    typealias Value = ContentAreaPrefData

    /**
     When a preference key value has not been set explicitly, SwiftUI will use this defaultValue.
     */
    static var defaultValue: ContentAreaPrefData = ContentAreaPrefData(height: 0)

    /**
     reduce: This is a static function that SwiftUI will use to merge all the key values found in the view tree. Normally, you use it to accumulate all the values it receives, but you can do whatever you want. In our case, when SwiftUI goes through the tree, it will collect the preference key values and store them together in a single array, which we will be able to access later. You should know that Values are supplied to the reduce function in view-tree order. We’ll come back to that in another example, as the order is not relevant here.
     */
    static func reduce(value: inout ContentAreaPrefData, nextValue: () -> ContentAreaPrefData) {
        value = nextValue()
        NSLog("HEIGHT OF CONTENT AREA: \(value.height)")
    }
}
