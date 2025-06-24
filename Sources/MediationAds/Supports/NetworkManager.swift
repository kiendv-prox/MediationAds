//
//  InternetConnectionMonitor.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 13/08/2024.
//

import Combine
import SystemConfiguration

public class NetworkManager: @unchecked Sendable {
    public static let shared = NetworkManager()
    
    private let networkStatusSubject = PassthroughSubject<Bool, Never>()
    
    @Published public var isNetwordConnected: Bool = false
    public var isConnected: AnyPublisher<Bool, Never> {
        networkStatusSubject.eraseToAnyPublisher()
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        var context = SCNetworkReachabilityContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "google.com") else {
            networkStatusSubject.send(true)
            isNetwordConnected = true
            return
        }
        SCNetworkReachabilitySetCallback(reachability, { (_, flags, info) in
            let isConnected = flags.contains(.reachable) && !flags.contains(.connectionRequired)
            
            guard let info else {
                return
            }
            let monitor = Unmanaged<NetworkManager>.fromOpaque(info).takeUnretainedValue()
            monitor.isNetwordConnected = isConnected
            monitor.networkStatusSubject.send(isConnected)
        }, &context)
        
        SCNetworkReachabilitySetDispatchQueue(reachability, DispatchQueue.global(qos: .background))
    }
}
