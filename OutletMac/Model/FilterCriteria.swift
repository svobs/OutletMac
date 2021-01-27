//
//  FilterCriteria.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//  Copyright © 2021 Ibotta. All rights reserved.
//

enum Ternary : UInt32 {
  case FALSE = 0
  case TRUE = 1
  case NOT_SPECIFIED = 2
}

class FilterCriteria: CustomStringConvertible {
  let searchQuery: String
  let isIgnoreCase: Bool
  let isTrashed: Ternary
  let isShared: Ternary
  let showSubtreesOfMatches: Bool
  
  init(searchQuery: String = "", isTrashed: Ternary = .NOT_SPECIFIED, isShared: Ternary = .NOT_SPECIFIED, isIgnoreCase: Bool = false,
       showSubtreesOfMatches: Bool = false) {
    self.searchQuery = searchQuery
    self.isTrashed = isTrashed
    self.isShared = isShared
    self.isIgnoreCase = isIgnoreCase
    self.showSubtreesOfMatches = showSubtreesOfMatches
  }
  
  func hasCriteria() -> Bool {
    return searchQuery != "" || isTrashed != .NOT_SPECIFIED || isShared != .NOT_SPECIFIED
  }
  
  var description: String {
    return "FilterCriteria(q=\"\(searchQuery)\" trashed=\(isTrashed) shared=\(isShared) ignoreCase=\(isIgnoreCase) showSubtrees=\(showSubtreesOfMatches))"
  }
}
