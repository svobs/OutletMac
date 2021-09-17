//
//  HoldOffTimer.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/26.
//
import SwiftUI

class HoldOffTimer {
  private var timer: Timer? = nil
  private let holdoffTimeSec: Double
  private let callback: NoArgVoidFunc
  // Cannot use DispatchQueue with Timer because it requires a runtime loop. Just use a lock:
  private let lock = NSLock()

  init(_ holdoffTimeMS: Int, _ callback: @escaping NoArgVoidFunc) {
    self.holdoffTimeSec = Double(holdoffTimeMS) / 1000.0
    self.callback = callback
  }

  func cancel() {
    lock.lock()
    defer {
      lock.unlock()
    }
    self.timer?.invalidate()
  }

  func reschedule() {
    self.cancel()

    lock.lock()
    defer {
      lock.unlock()
    }

    let timer = Timer.scheduledTimer(timeInterval: self.holdoffTimeSec, target: self, selector: #selector(self.callbackWrapper), userInfo: nil, repeats: false)
    timer.tolerance = TIMER_TOLERANCE_SEC
    self.timer = timer
  }

  @objc private func callbackWrapper() {
    self.callback()
  }
}
