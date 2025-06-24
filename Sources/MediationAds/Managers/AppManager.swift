//
//  AppManager.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 02/08/2024.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseRemoteConfig
import GoogleMobileAds
import AppLovinSDK
import FBAudienceNetwork

public class AppManager: ObservableObject {
    public static let shared = AppManager()
    
    public enum State {
        case unknow
        case loading
        case success
        case timeout
    }
    
    public enum DebugType {
        case event
        case consent(Bool)
        case ad(MonetizationNetwork)
    }
    
    enum Keys {
        static let consentKey = "CMP"
    }
    
    @Published private(set) var state: State = .unknow
    private let timeout = 15.0
    private var subscriptions = Set<AnyCancellable>()
    private var didError: Handler?
    private var didConnectedConfigure = false
    private(set) var testDeviceIdentifiers = [String]()
    private(set) var debugLogEvent = false
    private var appConfig: AppConfig!
    private(set) var testModeMax = false
    
    private lazy var releaseManager = ReleaseManager.shared
    private let networkManager = NetworkManager.shared
    private var remoteManager: RemoteManager!
    private lazy var consentManager = ConsentManager.shared
    
    @Published public var adConfigStatus: Bool = false
    @Published public var configStatus: Bool = false
    private lazy var networkConnectSubject = PassthroughSubject<Bool, Never>()
    private lazy var remoteConfigSubject = PassthroughSubject<Data, Never>()
    private lazy var timeoutConfigSubject = PassthroughSubject<Bool, Never>()
    private var timeoutTimer: Timer?
    
    public func initialize(app config: AppConfig) {
        self.appConfig = config
        
        guard state != .loading else { return }
        state = .loading
        
        
        print("[MediationAd] [AppManager] Start config!")
        LogEventManager.shared.log(event: .appManagerStartConfig)
        
        initSdkConfigture()
        addObservers()
        registerTimeout()
    }
    
//    public func initialize(appID: String,
//                           issuerID: String,
//                           keyID: String,
//                           privateKey: String,
//                           adConfigKey: String,
//                           defaultData: Data,
//                           maxSdkKey: String? = nil,
//                           devKey: String? = nil,
//                           trackingTimeout: Double? = nil,
//                           completed: @escaping RemoteHandler,
//                           didError: Handler? = nil
//    ) {
//        
//        guard state != .loading else {
//            return
//        }
//        self.state = .loading
//        self.didError = didError
//        
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutConfig)
//        
//        print("[MediationAd] [AppManager] Start config!")
//        LogEventManager.shared.log(event: .appManagerStartConfig)
//        NetworkManager.shared.isConnected
//            .sink { [weak self] isConnected in
//                guard let self else {
//                    return
//                }
//                guard isConnected else {
//                    return
//                }
//                guard state == .loading else {
//                    return
//                }
//                self.state = .success
//                print("[MediationAd] [AppManager] Did setup!")
//                let time = TimeManager.shared.end(event: .appManagerConfig)
//                LogEventManager.shared.log(event: .appManagerSuccess(time))
//                
//                RemoteManager.shared.remoteSubject
//                    .sink { state in
//                        completed(state, RemoteManager.shared.remoteConfig)
//                        
//                        switch state {
//                        case .success:
//                            let consentData = RemoteManager.shared.remoteConfig.configValue(forKey: Keys.consentKey).dataValue
//                            ConsentManager.shared.update(consentData: consentData)
//                        default:
//                            break
//                        }
//                    }.store(in: &subscriptions)
//                
//                Publishers.Zip3(ReleaseManager.shared.releaseSubject,
//                                ConsentManager.shared.consentSubject,
//                                RemoteManager.shared.remoteSubject)
//                .sink { releaseState, consentState, remoteState in
//                    print("[MediationAd] [AppManager] (Release: \(releaseState)) - (Consent: \(consentState)) - (Remote: \(remoteState))")
//                    
//                    let adConfigData = RemoteManager.shared.remoteConfig.configValue(forKey: adConfigKey).dataValue
//                    AdManager.shared.register(isRelease: releaseState == .live || releaseState == .error,
//                                              isConsent: consentState == .allow || consentState == .error,
//                                              defaultData: defaultData,
//                                              remoteData: adConfigData)
//                }.store(in: &subscriptions)
//                
//                ReleaseManager.shared.initialize(appID: appID,
//                                                 keyID: keyID,
//                                                 issuerID: issuerID,
//                                                 privateKey: privateKey)
//                ConsentManager.shared.initialize(maxSdkKey: maxSdkKey)
//                RemoteManager.shared.initialize()
//                
//                if let devKey {
//                    TrackingManager.shared.initialize(devKey: devKey,
//                                                      appID: appID,
//                                                      timeout: trackingTimeout)
//                }
//            }.store(in: &subscriptions)
//    }
    
    public func setTest(_ testDeviceIdentifiers: [String], testModeMax: Bool = false) {
        self.testDeviceIdentifiers = testDeviceIdentifiers
        self.testModeMax = testModeMax
    }
    
    public func activeDebug(_ type: DebugType) {
        switch type {
        case .event:
            self.debugLogEvent = true
        case .ad(let monetizationNetwork):
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIdentifiers
            
            switch monetizationNetwork {
            case .admob:
                guard let topVC = UIApplication.topViewController() else {
                    return
                }
                MobileAds.shared.presentAdInspector(from: topVC) { error in
                    print("[MediationAd] [AppManager] Present adInspector! (\(String(describing: error)))")
                }
            case .max:
                ALSdk.shared().showMediationDebugger()
            }
        case .consent(let reset):
            ConsentManager.shared.activeDebug(reset: reset)
        }
    }
}

private extension AppManager {
    private func addObservers() {
        Publishers.CombineLatest3(releaseManager.releaseSubject, remoteConfigSubject, consentManager.consentSubject)
            .sink(receiveValue: { [weak self] release, remoteData, consent in
                guard let self else { return }
                let isRelease = release == .live || release == .error
                let isConsent = consent == .allow || consent == .error
                #if DEBUG
                AdManager.shared.register(isRelease: isRelease,
                                          isConsent: isConsent,
                                          defaultData: appConfig.defaultData,
                                          remoteData: appConfig.defaultData)
                #else
                AdManager.shared.register(isRelease: isRelease,
                                          isConsent: isConsent,
                                          defaultData: appConfig.defaultData,
                                          remoteData: remoteData)
                #endif
                if !adConfigStatus {
                    adConfigStatus = true
                }
                if !configStatus {
                    configStatus = true
                }
                releaseTimeout()
            }).store(in: &subscriptions)
        
        
        networkManager.$isNetwordConnected
            .sink(receiveValue: { [weak self] isConnected in
                guard let self else { return }
                networkConnectSubject.send(isConnected)
                guard isConnected, state == .loading else { return }
                
                state = .success
                
                if remoteManager != nil {
                    remoteManager.initialize()
                }
                
                initilizedBeforeNetworkConnected()
                consentManager.initialize(maxSdkKey: appConfig.maxSdkKey, trackingManager: TrackingManager.shared)
            }).store(in: &subscriptions)
        
        timeoutConfigSubject.sink(receiveValue: { [weak self] value in
            guard let self else { return }
            if !configStatus {
                configStatus = true
            }
        })
        .store(in: &subscriptions)
        
    }
}

private extension AppManager {
    private func initilizedBeforeNetworkConnected() {
        guard !didConnectedConfigure else { return }
        didConnectedConfigure = true
        
        remoteManager = RemoteManager.shared
        remoteManager.initialize()
        releaseManager.initialize(appID: appConfig.appID,
                                  keyID: appConfig.keyID,
                                  issuerID: appConfig.issuerID,
                                  privateKey: appConfig.privateKey)
        consentManager.initialize(maxSdkKey: appConfig.maxSdkKey, trackingManager: TrackingManager.shared)
        
        remoteManager.remoteSubject.sink { [weak self] state in
            guard let self else { return }
            guard state == .success else {return}
            let data = remoteManager.remoteConfig.configValue(forKey: appConfig.adConfigKey).dataValue
            remoteConfigSubject.send(data)
            consentManager.update(consentData: data)
        }.store(in: &subscriptions)
        
    }
    
    private func initSdkConfigture() {
        FirebaseApp.configure()
    }
}

extension AppManager {
    private func timeoutConfig() {
        guard state == .loading else {
            return
        }
        self.state = .timeout
        print("[MediationAd] [AppManager] timeout!")
        LogEventManager.shared.log(event: .appManagerTimeout)
        didError?()
    }
}

extension AppManager {
    private func registerTimeout() {
        guard timeoutTimer == nil else {return}
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false, block: { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            timeoutConfigSubject.send(true)
            releaseTimeout()
        })
    }
    
    private func releaseTimeout() {
        guard timeoutTimer != nil else {return}
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}
