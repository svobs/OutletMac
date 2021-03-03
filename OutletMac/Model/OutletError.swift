//
//  OutletError.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//  Copyright © 2021 Ibotta. All rights reserved.
//

enum OutletError: Error {
  case invalidOperation(String? = nil)
  case invalidState(String? = nil)
  case grpcFailure(String? = nil)

  case maxResultsExceeded(actualCount: UInt32)
}
