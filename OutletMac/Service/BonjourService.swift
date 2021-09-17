//
// Created by Matthew Svoboda on 21/6/29.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import Foundation

struct IPPort {
    let ip: String
    let port: Int
}

typealias SuccessHandler<Result> = (_ result: Result) -> Void
typealias ErrorHandler = (_ error: Error) -> Void

class BonjourService: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    // Local service browser
    private var browser: NetServiceBrowser?

    // Instance of the service that we're looking for
    private var service: NetService?

    private var successHandler: SuccessHandler<IPPort>? = nil
    private var errorHandler: ErrorHandler? = nil

    func startDiscovery(onSuccess: @escaping SuccessHandler<IPPort>, onError: @escaping ErrorHandler) {
        stopDiscovery()

        self.successHandler = onSuccess
        self.errorHandler = onError

        NSLog("DEBUG [BonjourService] Starting discovery...")
        // Setup the browser
        browser = NetServiceBrowser()
//        browser!.includesPeerToPeer = true
        browser!.delegate = self
//        browser!.searchForRegistrationDomains()
        browser!.searchForServices(ofType: BONJOUR_SERVICE_TYPE, inDomain: BONJOUR_SERVICE_DOMAIN)
    }

    func stopDiscovery() {
        NSLog("DEBUG [BonjourService] Stopping discovery")
        // Make sure to reset the last known service if we want to run this a few times
        service = nil
        browser?.stop()

        self.successHandler = nil
        self.errorHandler = nil
    }

    // MARK: Service discovery

    // WillSearch
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        NSLog("DEBUG [BonjourService] Search beginning")
    }

    // DidNotResolve
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        NSLog("ERROR [BonjourService] Resolve error: (sender=\(sender)) errors=\(errorDict)")
        if let errorHandler = self.errorHandler {
            errorHandler(OutletError.bonjourFailure(("ERROR [BonjourService] Resolve error: (sender=\(sender)) errors=\(errorDict)")))
        }
        stopDiscovery()
    }

    // DidNotSearch
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        NSLog("ERROR NetServiceBrowser returned DidNotSearch: \(errorDict)")
        if let errorHandler = self.errorHandler {
            errorHandler(OutletError.bonjourFailure("NetServiceBrowser returned DidNotSearch: \(errorDict)"))
        }
    }

    // DidStopSearch
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        NSLog("DEBUG [BonjourService] Search stopped")
    }

    // DidFind
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind svc: NetService, moreComing: Bool) {
        NSLog("INFO  [BonjourService] Discovered service: name='\(svc.name)' type='\(svc.type)' domain='\(svc.domain)'")

        // We dont want to discover more services, just need the first one
        if service != nil {
            return
        }

        // We stop after we find first service
        browser.stop()

        // Resolve the service in 5 seconds
        service = svc
        service!.delegate = self
        service!.resolve(withTimeout: BONJOUR_RESOLUTION_TIMEOUT_SEC)
    }

    // DidFindDomain
    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        NSLog("DEBUG [BonjourService] found domain: \(domainString)")
    }

    // DidRemoveDomain
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        NSLog("DEBUG [BonjourService] Domain removed: '\(domainString)'")
    }

    // DidResolveAddress
    func netServiceDidResolveAddress(_ sender: NetService) {
        NSLog("DEBUG [BonjourService] netServiceDidResolveAddress() entered")

        // Find the IPV4 address
        if let serviceIp = resolveIPv4(addresses: sender.addresses!) {
            NSLog("DEBUG [BonjourService] Resolved service: ip=\(serviceIp) port=\(sender.port)")

            let ipPort = IPPort(ip: serviceIp, port: sender.port)

            if let successHandler = self.successHandler {
                successHandler(ipPort)
            }
        } else {
            NSLog("ERROR [BonjourService] Did not find IPv4 address")
            if let errorHandler = self.errorHandler {
                errorHandler(OutletError.bonjourFailure("Could not resolve IPv4 address!"))
            }
        }

    }

    // DidNotPublish
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        NSLog("ERROR [BonjourService] DidNotPublish: \(errorDict)")
        if let errorHandler = self.errorHandler {
            errorHandler(OutletError.bonjourFailure("ERROR [BonjourService] DidNotPublish: \(errorDict)"))
        }
    }

    // WillPublish
    func netServiceWillPublish(_ sender: NetService) {
        NSLog("DEBUG [BonjourService] Service will publish, apparently")
    }

    // DidPublish
    func netServiceDidPublish(_ sender: NetService) {
        NSLog("DEBUG [BonjourService] NetService published")
    }

    // DidStop
    func netServiceDidStop(_ sender: NetService) {
        NSLog("DEBUG [BonjourService] NetService stopped")
        stopDiscovery()
    }

    // Find an IPv4 address from the service address data
    private func resolveIPv4(addresses: [Data]) -> String? {
        var result: String?

        for addr in addresses {
            let data = addr as NSData
            var storage = sockaddr_storage()
            data.getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)

            if Int32(storage.ss_family) == AF_INET {
                let addr4 = withUnsafePointer(to: &storage) {
                    $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                        $0.pointee
                    }
                }

                if let ip = String(cString: inet_ntoa(addr4.sin_addr), encoding: .ascii) {
                    result = ip
                    break
                }
            }
        }

        return result
    }
}
