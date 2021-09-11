//
//  HasLifecycle.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-02.
//

protocol HasLifecycle: AnyObject {
  func start() throws
  func shutdown() throws
}
