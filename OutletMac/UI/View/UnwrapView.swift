//
//  UnwrapView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-09.
//

import SwiftUI

/*
 From https://www.swiftbysundell.com/tips/optional-swiftui-views
 */
struct Unwrap<Value, Content: View>: View {
  private let value: Value?
  private let contentProvider: (Value) -> Content

  init(_ value: Value?,
       @ViewBuilder content: @escaping (Value) -> Content) {
    self.value = value
    self.contentProvider = content
  }

  var body: some View {
    value.map(contentProvider)
  }
}
