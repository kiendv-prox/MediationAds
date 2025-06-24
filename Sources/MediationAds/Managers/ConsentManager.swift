//
//  ConsentManager.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 02/08/2024.
//

import UIKit
import UserMessagingPlatform
import GoogleMobileAds
import Combine
import AppLovinSDK
import MTGSDK
import FBAudienceNetwork
import VungleAdsSDK
import IASDKCore

public class ConsentManager: @unchecked Sendable {
    public static let shared = ConsentManager()
    
    enum Keys {
        static let cache = "CONSENT_CACHE"
    }
    
    public enum State: String {
        case unknow
        case allow
        case reject
        case error
    }
    
    @Published public private(set) var consentState: State = .unknow
    let consentSubject = PassthroughSubject<State, Never>()
    private var didRequestConsent = false
    private let timeout = 30.0
    private var isDebug = false
    private var maxSdkKey: String?
//    private var consentConfig: ConsentConfig?
    private var trackingManager: TrackingManager!
    private var isInitilizedSdk: Bool = false
    
    
    public func requestConsentUpdate(completed: @escaping ConsentHandler) {
        LogEventManager.shared.log(event: .consentManagerUpdateRequest)
        guard let viewController = UIApplication.topViewController() else {
            LogEventManager.shared.log(event: .consentManagerUpdateError)
            completed(.error)
            return
        }
        
        ConsentForm.presentPrivacyOptionsForm(from: viewController) { [weak self] formError in
            guard let self else {
                return
            }
            
            guard formError == nil else {
                print("[MediationAd] [ConsentManager] Form error - \(formError!.localizedDescription)!")
                LogEventManager.shared.log(event: .consentManagerUpdateError)
                completed(.error)
                return
            }
            
            guard consentState != .allow else {
                completed(.allow)
                return
            }
            
            let canShowAds = canShowAds()
            let state: State = canShowAds ? .allow : .reject
            ALPrivacySettings.setHasUserConsent(canShowAds)
            MTGSDK.sharedInstance().consentStatus = canShowAds
            VunglePrivacySettings.setGDPRStatus(canShowAds)
            IASDKCore.sharedInstance().gdprConsent = canShowAds ? IAGDPRConsentType.given : IAGDPRConsentType.denied
            
            self.consentState = state
            
            if canShowAds {
                LogEventManager.shared.log(event: .consentManagerUpdateAgree)
            } else {
                LogEventManager.shared.log(event: .consentManagerUpdateReject)
            }
            
            switch state {
            case .allow:
                startSdk {
                    completed(state)
                }
            default:
                completed(state)
            }
        }
    }
    
    public func requestConsentIfRequired() async throws {
        guard !didRequestConsent else {
            return
        }
        self.didRequestConsent = true
        
        print("[MediationAd] [ConsentManager] Check consent!")
        LogEventManager.shared.log(event: .consentManagerStartCheck)
        
        let umpParams = getGoogleConsentConfigture()
        
        do {
            print("[MediationAd] [ConsentManager] Request consent!")
            LogEventManager.shared.log(event: .consentManagerRequest)
            
            try await requestConsentInfoUpdate(params: umpParams)
            
            do {
                try await presentConsentIfRequired()
            } catch {
                print("[MediationAd] [ConsentManager] Load and present error - \(error.localizedDescription)!")
                LogEventManager.shared.log(event: .consentManagerFormError)
                throw error
            }
            
        } catch {
            print("[MediationAd] [ConsentManager] Request consent error - \(error.localizedDescription)!")
            LogEventManager.shared.log(event: .consentManagerInfoError)
            throw error
        }
    }
    
    private func requestConsentInfoUpdate(params: RequestParameters?) async throws {
//        print("[MediationAd] [ConsentManager] Request consent!")
//        LogEventManager.shared.log(event: .consentManagerRequest)
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else { return }
            ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] error in
                guard let self else { return }
                if let error {
//                    print("[MediationAd] [ConsentManager] Request consent error - \(error.localizedDescription)!")
//                    LogEventManager.shared.log(event: .consentManagerInfoError)
//                    change(state: .error)
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    @MainActor
    private func presentConsentIfRequired() async throws {
        guard let controller = UIApplication.topViewController() else {
            throw NSError(domain: "Top View Controller Invalid", code: 404)
        }
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else { return }
            ConsentForm.loadAndPresentIfRequired(from: controller) { [weak self] error in
                guard let self else { return }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension ConsentManager {
    func initialize(maxSdkKey: String?, trackingManager: TrackingManager) {
        self.maxSdkKey = maxSdkKey
        self.trackingManager = trackingManager
        
        LogEventManager.shared.log(event: .consentManagerUseCache)
        if consentConfig == nil {
            print("[MediationAd] [ConsentManager] Invalid (ConsentConfig) format!")
            LogEventManager.shared.log(event: .consentManagerInvalidFormat)
        }
        
        Task {
            var isConsentError: Bool = false
            do {
                try await requestConsentIfRequired()
            } catch {
                isConsentError = true
            }
            
            let _ = await trackingManager.requestAuthorization()
            
            if isConsentError {
                change(state: .error)
            } else {
                change(state: .allow)
            }
        }
    }
    
    func activeDebug(reset: Bool) {
        self.isDebug = true
        if reset {
            ConsentInformation.shared.reset()
        }
    }
    
    func update(consentData: Data) {
        consentConfig = try? JSONDecoder().decode(ConsentConfig.self, from: consentData)
    }
}

extension ConsentManager {
//    private func updateCache() {
//        guard let consentConfig else {
//            return
//        }
//        guard let data = try? JSONEncoder().encode(consentConfig) else {
//            return
//        }
//        UserDefaults.standard.set(data, forKey: Keys.cache)
//    }
//    
//    private func decoding(data: Data) {
//        guard let consentConfig = try? JSONDecoder().decode(ConsentConfig.self, from: data) else {
//            print("[MediationAd] [ConsentManager] Invalid (ConsentConfig) format!")
//            LogEventManager.shared.log(event: .consentManagerInvalidFormat)
//            return
//        }
//        self.consentConfig = consentConfig
//        updateCache()
//        check()
//    }
//    
//    private func fetch() {
//        guard let cacheData = UserDefaults.standard.data(forKey: Keys.cache) else {
//            return
//        }
//        LogEventManager.shared.log(event: .consentManagerUseCache)
//        decoding(data: cacheData)
//    }
//    
//    private func check() {
//        guard !didRequestConsent else {
//            return
//        }
//        self.didRequestConsent = true
//        
//        print("[MediationAd] [ConsentManager] Check consent!")
//        LogEventManager.shared.log(event: .consentManagerStartCheck)
//        
//        let parameters = RequestParameters()
//        parameters.isTaggedForUnderAgeOfConsent = false
//        
//        if isDebug {
//            let debugSettings = DebugSettings()
//            debugSettings.testDeviceIdentifiers = AppManager.shared.testDeviceIdentifiers
//            debugSettings.geography = .EEA
//            parameters.debugSettings = debugSettings
//        } else {
//            guard let consentConfig, consentConfig.status else {
//                print("[MediationAd] [ConsentManager] Not request consent!")
//                LogEventManager.shared.log(event: .consentManagerNotRequest)
//                change(state: .allow)
//                return
//            }
//        }
//        
//        
//        
//        print("[MediationAd] [ConsentManager] Request consent!")
//        LogEventManager.shared.log(event: .consentManagerRequest)
//        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] requestConsentError in
//            guard let self else {
//                return
//            }
//            if let requestConsentError {
//                print("[MediationAd] [ConsentManager] Request consent error - \(requestConsentError.localizedDescription)!")
//                LogEventManager.shared.log(event: .consentManagerInfoError)
//                change(state: .error)
//                return
//            }
//            
//            guard let viewController = UIApplication.topViewController() else {
//                change(state: .error)
//                return
//            }
//            
//            ConsentForm.loadAndPresentIfRequired(from: viewController) { [weak self] loadAndPresentError in
//                guard let self else {
//                    return
//                }
//                if let loadAndPresentError {
//                    print("[MediationAd] [ConsentManager] Load and present error - \(loadAndPresentError.localizedDescription)!")
//                    LogEventManager.shared.log(event: .consentManagerFormError)
//                    change(state: .error)
//                    return
//                }
//                guard isGDPR() else {
//                    print("[MediationAd] [ConsentManager] Auto agree consent GDPR!")
//                    LogEventManager.shared.log(event: .consentManagerAutoAgreeGDPR)
//                    change(state: .allow)
//                    return
//                }
//                
//                let canShowAds = canShowAds()
//                if canShowAds {
//                    print("[MediationAd] [ConsentManager] Agree consent!")
//                } else {
//                    print("[MediationAd] [ConsentManager] Reject consent!")
//                }
//                change(state: canShowAds ? .allow : .reject)
//            }
//        }
//        
//        if canShowAds() {
//            print("[MediationAd] [ConsentManager] Auto agree consent!")
//            LogEventManager.shared.log(event: .consentManagerAutoAgree)
//            change(state: .allow)
//        }
//    }
    
    private func change(state: State) {
        guard
            consentState == .unknow,
            state != .unknow
        else {
            return
        }
        
        configtureSdkBeforeConsent(state: state)
        
        let time = TimeManager.shared.end(event: .consentManagerCheck)
        switch state {
        case .allow:
            LogEventManager.shared.log(event: .consentManagerAgree(time))
        case .reject:
            LogEventManager.shared.log(event: .consentManagerReject(time))
        case .error:
            LogEventManager.shared.log(event: .consentManagerError(time))
        default:
            break
        }
        
        self.consentState = state
        switch state {
        case .allow, .error:
            guard isInitilizedSdk else {
                send(state: state)
                return
            }
            Task {
                await initGoogleAds()
                try? await initApplovinMax()
                
            }
            startSdk() { [weak self] in
                guard let self else {
                    return
                }
                send(state: state)
            }
        default:
            send(state: state)
        }
    }
    
    private func startSdk(completed: @escaping Handler) {
        MobileAds.shared.start { status in
            // Optional: Log each adapter's initialization latency.
            let adapterStatuses = status.adapterStatusesByClassName
            for adapter in adapterStatuses {
                let adapterStatus = adapter.value
                NSLog("[MediationAd] [AdapterName] %@, Description: %@, Latency: %f", adapter.key,
                      adapterStatus.description, adapterStatus.latency)
            }
            if let maxSdkKey = self.maxSdkKey {
                let maxInitConfig = ALSdkInitializationConfiguration(sdkKey: maxSdkKey) { builder in
                    builder.mediationProvider = ALMediationProviderMAX
                    if AppManager.shared.testModeMax {
                        builder.testDeviceAdvertisingIdentifiers = AppManager.shared.testDeviceIdentifiers
                    }
                }
                ALSdk.shared().initialize(with: maxInitConfig) { sdkConfig in
                    completed()
                }
            } else {
                completed()
            }
        }
    }
    
    
    
    private func send(state: State) {
        consentSubject.send(state)
    }
    
    private func isGDPR() -> Bool {
        let settings = UserDefaults.standard
        let gdpr = settings.integer(forKey: "IABTCF_gdprApplies")
        return gdpr == 1
    }
    
    private func canShowAds() -> Bool {
        let userDefaults = UserDefaults.standard
        
        let purposeConsent = userDefaults.string(forKey: "IABTCF_PurposeConsents") ?? ""
        let vendorConsent = userDefaults.string(forKey: "IABTCF_VendorConsents") ?? ""
        let vendorLI = userDefaults.string(forKey: "IABTCF_VendorLegitimateInterests") ?? ""
        let purposeLI = userDefaults.string(forKey: "IABTCF_PurposeLegitimateInterests") ?? ""
        
        let googleId = 755
        let hasGoogleVendorConsent = hasAttribute(input: vendorConsent, index: googleId)
        let hasGoogleVendorLI = hasAttribute(input: vendorLI, index: googleId)
        
        return hasConsentFor([1], purposeConsent, hasGoogleVendorConsent)
        && hasConsentOrLegitimateInterestFor([2,7,9,10],
                                             purposeConsent,
                                             purposeLI,
                                             hasGoogleVendorConsent,
                                             hasGoogleVendorLI)
    }
    
    private func hasAttribute(input: String, index: Int) -> Bool {
        return input.count >= index && String(Array(input)[index - 1]) == "1"
    }
    
    private func hasConsentFor(_ purposes: [Int], _ purposeConsent: String, _ hasVendorConsent: Bool) -> Bool {
        return purposes.allSatisfy { i in hasAttribute(input: purposeConsent, index: i) } && hasVendorConsent
    }
    
    private func hasConsentOrLegitimateInterestFor(_ purposes: [Int],
                                                   _ purposeConsent: String,
                                                   _ purposeLI: String,
                                                   _ hasVendorConsent: Bool,
                                                   _ hasVendorLI: Bool
    ) -> Bool {
        return purposes.allSatisfy { i in
            (hasAttribute(input: purposeLI, index: i) && hasVendorLI) ||
            (hasAttribute(input: purposeConsent, index: i) && hasVendorConsent)
        }
    }
    
}

// MARK: - SDK Configture
extension ConsentManager {
    @discardableResult
    private func initGoogleAds() async -> InitializationStatus  {
        let status = await MobileAds.shared.start()
        let adapterStatuses = status.adapterStatusesByClassName
        for adapter in adapterStatuses {
            let adapterStatus = adapter.value
            NSLog("[MediationAd] [AdapterName] %@, Description: %@, Latency: %f", adapter.key,
                  adapterStatus.description, adapterStatus.latency)
        }
        return status
    }
    
    private func initApplovinMax() async throws {
        guard let maxSdkKey else { throw NSError(domain: "Applovin SDK Config Key Invalid", code: 404) }
        let maxConfig = ALSdkInitializationConfiguration(sdkKey: maxSdkKey) { [weak self] builder in
            builder.mediationProvider = ALMediationProviderMAX
            guard let self else { return }
            if isDebug,
                let idVendor = UIDevice.current.identifierForVendor?.uuidString {
                builder.testDeviceAdvertisingIdentifiers = [idVendor]
            }
        }
        
        return await withCheckedContinuation { continuation in
            ALSdk.shared().initialize(with: maxConfig) { _ in
                continuation.resume()
            }
        }
    }
    
    private func getGoogleConsentConfigture() -> RequestParameters {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        if isDebug {
            let debugSettings = DebugSettings()
            debugSettings.testDeviceIdentifiers = AppManager.shared.testDeviceIdentifiers
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
//        else {
//            if let consentConfig, consentConfig.status {
//                print("[MediationAd] [ConsentManager] Not request consent!")
//                LogEventManager.shared.log(event: .consentManagerNotRequest)
//                change(state: .allow)
//                return nil
//            }
//        }
        
        return parameters
    }
    
    private func configtureSdkBeforeConsent(state: State) {
        let hasConsent = state == .allow || consentState == .error
        ALPrivacySettings.setHasUserConsent(hasConsent)
        ALPrivacySettings.setDoNotSell(true)
//        #if DEBUG
        /// Facebook Mediation TestMode require isAgeRestrictedUser false
//        ALPrivacySettings.setIsAgeRestrictedUser(false)
//        #endif
        MTGSDK.sharedInstance().consentStatus = hasConsent
        MTGSDK.sharedInstance().doNotTrackStatus = false
        VunglePrivacySettings.setGDPRStatus(hasConsent)
        if let nowVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            VunglePrivacySettings.setGDPRMessageVersion(nowVersionString)
        }
        IASDKCore.sharedInstance().gdprConsent = hasConsent ? IAGDPRConsentType.given : IAGDPRConsentType.denied
        IASDKCore.sharedInstance().gdprConsentString = "myGdprConsentString"
        
        FBAudienceNetworkAds.initialize(with: nil, completionHandler: nil)
        FBAdSettings.setDataProcessingOptions([])
        FBAdSettings.setAdvertiserTrackingEnabled(true)
    }
}

extension ConsentManager {
    var consentConfig: ConsentConfig? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.cache) else {
                return nil
            }
            return try? JSONDecoder().decode(ConsentConfig.self, from: data)
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: Keys.cache)
        }
    }
}
