//
// Created by Matthew Svoboda on 21/9/8.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Foundation

/**
 CLASS GRPCClientBackend
 */
class BackendConnectionState: ObservableObject {
    @Published var host: String
    @Published var port: Int

    @Published var conecutiveStreamFailCount: Int = 0
    @Published var isConnected: Bool = false
    @Published var isRelaunching: Bool = false

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}
