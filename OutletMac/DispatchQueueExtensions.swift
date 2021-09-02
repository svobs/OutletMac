//
// Created by Matthew Svoboda on 21/8/26.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Foundation

/**
 Adds functionality to detect & report which queue we're in.
 From: https://stackoverflow.com/questions/17475002/get-current-dispatch-queue
 See TaskRunner.swift for an example use.
 */

// MARK: private functionality

extension DispatchQueue {

    private struct QueueReference { weak var queue: DispatchQueue? }

    private static let key: DispatchSpecificKey<QueueReference> = {
        let key = DispatchSpecificKey<QueueReference>()
        setupSystemQueuesDetection(key: key)
        return key
    }()

    private static func _registerDetection(of queues: [DispatchQueue], key: DispatchSpecificKey<QueueReference>) {
        queues.forEach { $0.setSpecific(key: key, value: QueueReference(queue: $0)) }
    }

    private static func setupSystemQueuesDetection(key: DispatchSpecificKey<QueueReference>) {
        let queues: [DispatchQueue] = [
            .main,
            .global(qos: .background),
            .global(qos: .default),
            .global(qos: .unspecified),
            .global(qos: .userInitiated),
            .global(qos: .userInteractive),
            .global(qos: .utility)
        ]
        _registerDetection(of: queues, key: key)
    }
}

// MARK: public functionality

extension DispatchQueue {
    static func registerDetection(of queue: DispatchQueue) {
        _registerDetection(of: [queue], key: key)
    }

    static var currentQueueLabel: String? { current?.label }
    static var current: DispatchQueue? { getSpecific(key: key)?.queue }

    static func isExecutingIn(_ dq: DispatchQueue) -> Bool {
        let isExpected = DispatchQueue.current == dq
        if !isExpected {
            NSLog("ERROR We are in the wrong queue: '\(DispatchQueue.currentQueueLabel ?? "nil")' (expected: \(dq.label))")
        }
        return isExpected
    }

    static func isNotExecutingIn(_ dq: DispatchQueue) -> Bool {
        let isExpected = DispatchQueue.current != dq
        if !isExpected {
            NSLog("ERROR We should not be executing in: '\(DispatchQueue.currentQueueLabel ?? "nil")'")
        }
        return isExpected
    }
}
