//
//  TaskRunner.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/26.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import SwiftUI

class TaskRunner {
  let serialQueue = DispatchQueue(label: "Serial Queue") // custom dispatch queues are serial by default

  func execAsync(_ workItem: @escaping NoArgVoidFunc) {
    serialQueue.async(execute: workItem)
  }
}
