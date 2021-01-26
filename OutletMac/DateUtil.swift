//
//  DateUtil.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-25.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Foundation

class DateUtil {
  static func getCurrentTimeMS() -> UInt64 {
    return UInt64(Date().timeIntervalSince1970 * 1000)
  }
}
