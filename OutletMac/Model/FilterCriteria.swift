//
//  FilterCriteria.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//

enum Ternary : UInt32 {
  case FALSE = 0
  case TRUE = 1
  case NOT_SPECIFIED = 2
}

/**
 CLASS FilterCriteria
 */
class FilterCriteria: CustomStringConvertible {
  let searchQuery: String
  let isIgnoreCase: Bool
  let isTrashed: Ternary
  let isShared: Ternary
  let showAncestors: Bool
  
  init(searchQuery: String = "", isTrashed: Ternary = .NOT_SPECIFIED, isShared: Ternary = .NOT_SPECIFIED, isIgnoreCase: Bool = false,
       showAncestors: Bool = false) {
    self.searchQuery = searchQuery
    self.isTrashed = isTrashed
    self.isShared = isShared
    self.isIgnoreCase = isIgnoreCase
    self.showAncestors = showAncestors
  }
  
  func hasCriteria() -> Bool {
    return searchQuery != "" || isTrashed != .NOT_SPECIFIED || isShared != .NOT_SPECIFIED
  }
  
  var description: String {
    return "FilterCriteria(q=\"\(searchQuery)\" trashed=\(isTrashed) shared=\(isShared) ignoreCase=\(isIgnoreCase) showAncestors=\(showAncestors))"
  }
}
