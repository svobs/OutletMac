//
//  HoldOffTimer.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/26.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI

class HoldOffTimer {
  private var timer: Timer? = nil
  private let holdoffTimeSec: Double
  private let callback: NoArgVoidFunc

  init(_ holdoffTimeMS: Int, _ callback: @escaping NoArgVoidFunc) {
    self.holdoffTimeSec = Double(holdoffTimeMS) / 1000.0
    self.callback = callback
  }

  func cancel() {
    if self.timer != nil {
      self.timer?.invalidate()
    }
  }

  func reschedule() {
    NSLog("reschedule()")
    self.cancel()

    NSLog("Scheduling timer")
    let timer = Timer.scheduledTimer(timeInterval: self.holdoffTimeSec, target: self, selector: #selector(self.callbackWrapper), userInfo: nil, repeats: false)
    timer.tolerance = TIMER_TOLERANCE_SEC
    self.timer = timer
  }

  @objc private func callbackWrapper() {
    NSLog("callbackWrapper()")
    self.callback()
  }
}
