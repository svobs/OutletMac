//
//  FilterCriteria.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//  Copyright © 2021 Ibotta. All rights reserved.
//

enum Ternary : UInt {
  case FALSE = 0
  case TRUE = 1
  case NOT_SPECIFIED = 2
}

class FilterCriteria: CustomStringConvertible {
  let searchQuery: String
  let ignoreCase: Bool
  let isTrashed: Ternary
  let isShared: Ternary
  let showSubtreesOfMatches: Bool
  
  init(searchQuery: String = "", isTrashed: Ternary = .NOT_SPECIFIED, isShared: Ternary = .NOT_SPECIFIED, ignoreCase: Bool = false,
       showSubtreesOfMatches: Bool = false) {
    self.searchQuery = searchQuery
    self.isTrashed = isTrashed
    self.isShared = isShared
    self.ignoreCase = ignoreCase
    self.showSubtreesOfMatches = showSubtreesOfMatches
  }
  
  func hasCriteria() -> Bool {
    return searchQuery != "" || isTrashed != .NOT_SPECIFIED || isShared != .NOT_SPECIFIED
  }
  
  var description: String {
    return "FilterCriteria(q=\"\(searchQuery)\" trashed=\(isTrashed) shared=\(isShared) ignoreCase=\(ignoreCase) showSubtrees=\(showSubtreesOfMatches))"
  }
}
