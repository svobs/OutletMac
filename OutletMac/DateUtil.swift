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
    if timestamp_millis == nil {
      return ""
    }

    let unixTimestamp = Double(timestamp_millis!) / 1000.0
    let date = Date(timeIntervalSince1970: unixTimestamp)
    return dateFormatter.string(from: date)
  }
}
