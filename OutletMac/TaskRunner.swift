//
//  TaskRunner.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/26.
//
import SwiftUI

class TaskRunner {
  let serialQueue = DispatchQueue(label: "TaskRunner-serial-queue") // custom dispatch queues are serial by default

  init() {
    // See DispatchQueueExtensions.swift
    DispatchQueue.registerDetection(of: serialQueue)
  }

  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
    serialQueue.async(execute: workItem)
  }

  func execSync(_ workItem: @escaping NoArgVoidFunc) {
    serialQueue.sync(execute: workItem)
  }
}
