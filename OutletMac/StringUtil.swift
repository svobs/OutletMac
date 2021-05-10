//
//  StringUtil.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-05.
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

class StringUtil {
  private static let byteCountFormatter: ByteCountFormatter = makeByteCountFormatter()
  private static let largeNumberFormatter: NumberFormatter = makeLargeNumberFormatter()

  private static func makeByteCountFormatter() -> ByteCountFormatter {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = .useAll
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter
  }

  private static func makeLargeNumberFormatter() -> NumberFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal
    return numberFormatter
  }

  static func formatNumberWithCommas(_ largeNumber: UInt32) -> String {
    return largeNumberFormatter.string(from: NSNumber(value:largeNumber))!
  }

  static func formatByteCount(_ byteCount: UInt64?) -> String {
    guard let sizeBytes = byteCount else {
      return ""
    }
    return byteCountFormatter.string(fromByteCount: Int64(sizeBytes))
  }

  static func joinPaths(_ parentPath: String, _ childPath: String) -> String {
    return URL(fileURLWithPath: parentPath).appendingPathComponent(childPath).path
  }
}
