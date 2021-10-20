//
//  DateUtil.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//

import Foundation

class DateUtil {
  private static let dateFormatter: DateFormatter = makeDateFormatter()

  private static func makeDateFormatter() -> DateFormatter {
    let df = DateFormatter()
//    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
    df.timeZone = TimeZone.current
    df.locale = NSLocale.current
    df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return df
  }

  static func getCurrentTimeMS() -> UInt64 {
    return UInt64(Date().timeIntervalSince1970 * 1000)
  }

  static func formatTS(_ timestamp_millis: UInt64?) -> String {
    guard let timestamp_millis = timestamp_millis else {
      return ""
    }

    let unixTimestamp = Double(timestamp_millis) / 1000.0
    let date = Date(timeIntervalSince1970: unixTimestamp)
    return dateFormatter.string(from: date)
  }
}

extension DispatchTimeInterval {
  func toDouble() -> Double? {
    var result: Double? = nil

    switch self {
    case .seconds(let value):
      result = Double(value)
    case .milliseconds(let value):
      result = Double(value)*0.001
    case .microseconds(let value):
      result = Double(value)*0.000001
    case .nanoseconds(let value):
      result = Double(value)*0.000000001

    case .never:
      result = nil
    @unknown default:
      fatalError("DispatchTimeInterval.toDouble: unknown default!")
    }

    return result
  }

  func toString() -> String {
    if let doubleVal = self.toDouble() {
      return String(format: "%.3f sec", doubleVal)
    } else {
      return "never"
    }
  }
}
