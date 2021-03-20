//
//  IfView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/19.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

/**
 The if view extension: facilitates conditional modifiers
 From: https://fivestars.blog/swiftui/conditional-modifiers.html
 */
extension View {
  @ViewBuilder
  func `if`<Transform: View>(
    _ condition: Bool,
    transform: (Self) -> Transform
  ) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}
