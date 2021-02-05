//
//  StringUtil.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-05.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

func quoted(_ str: String) -> String {
  return "\"\(str)\""
}

func quotedOrNil(_ str: String?) -> String {
  return str == nil ? "nil" : "\"\(str!)\""
}

func descOrNil(_ obj: CustomStringConvertible?) -> String {
  return obj == nil ? "nil" : obj!.description
}

func fromBoolOrNil(_ b: Bool?) -> String {
  return b == nil ? "nil" : String(b!)
}
