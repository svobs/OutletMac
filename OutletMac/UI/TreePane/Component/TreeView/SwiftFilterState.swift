//
// Created by Matthew Svoboda on 21/9/7.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Foundation
import OutletCommon

/**
 CLASS SwiftFilterState

 SwiftUI ObservableObject version of FilterCriteria class.
 Note that this class uses "isMatchCase", which is the inverse of FilterCriteria's "isIgnoreCase"
 */
class SwiftFilterState: ObservableObject, CustomStringConvertible {
    // See: TreeController.onFilterChanged()
    var onChangeCallback: FilterStateCallback? = nil

    @Published var searchQuery: String {
        didSet {
            NSLog("DEBUG Search query changed: \(searchQuery)")
            if onChangeCallback != nil {
                onChangeCallback!(self)
            }
        }
    }
    @Published var isMatchCase: Bool {
        didSet {
            NSLog("DEBUG isMatchCase changed: \(isMatchCase)")
            if onChangeCallback != nil {
                onChangeCallback!(self)
            }
        }
    }

    @Published var isTrashed: Ternary {
        didSet {
            NSLog("DEBUG isTrashed changed: \(isTrashed)")
            if onChangeCallback != nil {
                onChangeCallback!(self)
            }
        }
    }
    @Published var isShared: Ternary {
        didSet {
            NSLog("DEBUG isShared changed: \(isShared)")
            if onChangeCallback != nil {
                onChangeCallback!(self)
            }
        }
    }
    @Published var showAncestors: Bool {
        didSet {
            NSLog("DEBUG showAncestors changed: \(showAncestors)")
            if onChangeCallback != nil {
                onChangeCallback!(self)
            }
        }
    }

    func isFlatList() -> Bool {
        let hasCriteria = self.hasCriteria()
        let notShowAncestors = !self.showAncestors
        return hasCriteria && notShowAncestors
    }

    func hasCriteria() -> Bool {
        return searchQuery != "" || isTrashed != .NOT_SPECIFIED || isShared != .NOT_SPECIFIED
    }

    init(onChangeCallback: FilterStateCallback? = nil, searchQuery: String, isMatchCase: Bool, isTrashed: Ternary, isShared: Ternary, showAncestors: Bool) {
        self.onChangeCallback = onChangeCallback
        self.searchQuery = searchQuery
        self.isMatchCase = isMatchCase
        self.isTrashed = isTrashed
        self.isShared = isShared
        self.showAncestors = showAncestors
    }

    func updateFrom(_ filter: FilterCriteria, onChangeCallback: FilterStateCallback? = nil) {
        self.onChangeCallback = onChangeCallback
        self.searchQuery = filter.searchQuery
        self.isMatchCase = !filter.isIgnoreCase
        self.isTrashed = filter.isTrashed
        self.isShared = filter.isShared
        self.showAncestors = filter.showAncestors
    }

    static func from(_ filter: FilterCriteria, onChangeCallback: FilterStateCallback? = nil) -> SwiftFilterState {
        return SwiftFilterState(onChangeCallback: onChangeCallback, searchQuery: filter.searchQuery, isMatchCase: !filter.isIgnoreCase, isTrashed: filter.isTrashed, isShared: filter.isShared, showAncestors: filter.showAncestors)
    }

    func toFilterCriteria() -> FilterCriteria {
        return FilterCriteria(searchQuery: searchQuery, isTrashed: isTrashed, isShared: isShared, isIgnoreCase: !isMatchCase, showAncestors: showAncestors)
    }

    var description: String {
        return "SwiftFilterState(q=\"\(searchQuery)\" trashed=\(isTrashed) shared=\(isShared) isMatchCase=\(isMatchCase) showAncestors=\(showAncestors))"
    }
}

typealias FilterStateCallback = (SwiftFilterState) -> Void
