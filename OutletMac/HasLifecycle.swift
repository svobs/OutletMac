//
//  HasLifecycle.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-02.
//  Copyright © 2021 Ibotta. All rights reserved.
//

protocol HasLifecycle {
  func start() throws
  func shutdown() throws
}
