//
//  OutletError.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-01-21.
//

enum OutletError: Error {
  case invalidArgument(String)
  case invalidOperation(String? = nil)
  case invalidState(String? = nil)
  case grpcFailure(String, String? = nil)  // 1st is complete msg, 2nd is gRPC msg
  case grpcConnectionDown(String? = nil)
  case bonjourFailure(String? = nil)

  case maxResultsExceeded(actualCount: UInt32)
}
