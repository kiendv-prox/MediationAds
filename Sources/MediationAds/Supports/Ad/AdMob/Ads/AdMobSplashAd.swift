//
//  SplashAd.swift
//
//
//  Created by Trịnh Xuân Minh on 06/09/2023.
//

import UIKit
import GoogleMobileAds
import AppsFlyerAdRevenue

class AdMobSplashAd: NSObject, ReuseAdProtocol {
    private var splashAd: InterstitialAd?
    private var adUnitID: String?
    private var placement: String?
    private var name: String?
    private var presentState = false
    private var isLoading = false
    private var timeout: Double?
    private var didResponse = false
    private var didLoadFail: Handler?
    private var didLoadSuccess: Handler?
    private var didFail: Handler?
    private var willPresent: Handler?
    private var didEarnReward: Handler?
    private var didHide: Handler?
    
    func config(didFail: Handler?, didSuccess: Handler?) {
        self.didLoadFail = didFail
        self.didLoadSuccess = didSuccess
    }
    
    func config(id: String, name: String) {
        self.adUnitID = id
        self.name = name
        load()
    }
    
    func config(timeout: Double) {
        self.timeout = timeout
    }
    
    func isPresent() -> Bool {
        return presentState
    }
    
    func isExist() -> Bool {
        return splashAd != nil
    }
    
    func show(placement: String,
              rootViewController: UIViewController,
              didFail: Handler?,
              willPresent: Handler?,
              didEarnReward: Handler?,
              didHide: Handler?
    ) {
        guard !presentState else {
            print("[MediationAd] [AdManager] [AdMob] [SplashAd] Display failure - ads are being displayed! (\(placement))")
            didFail?()
            return
        }
        LogEventManager.shared.log(event: .adShowRequest(.admob, placement))
        guard isExist() else {
            print("[MediationAd] [AdManager] [AdMob] [SplashAd] Display failure - not ready to show! (\(placement))")
            LogEventManager.shared.log(event: .adShowNoReady(.admob, placement))
            didFail?()
            return
        }
        LogEventManager.shared.log(event: .adShowReady(.admob, placement))
        print("[MediationAd] [AdManager] [AdMob] [SplashAd] Requested to show! (\(placement))")
        self.placement = placement
        self.didFail = didFail
        self.willPresent = willPresent
        self.didHide = didHide
        self.didEarnReward = didEarnReward
        splashAd?.present(from: rootViewController)
    }
}

extension AdMobSplashAd: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("[MediationAd] [AdManager] [AdMob] [SplashAd] Did fail to show content! (\(String(describing: name)))")
        if let placement {
            LogEventManager.shared.log(event: .adShowFail(.admob, placement, error))
        }
        didFail?()
        self.splashAd = nil
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[MediationAd] [AdManager] [AdMob] [SplashAd] Will display! (\(String(describing: name)))")
        if let placement {
            LogEventManager.shared.log(event: .adShowSuccess(.admob, placement))
        }
        willPresent?()
        self.presentState = true
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[MediationAd] [AdManager] [AdMob] [SplashAd] Did hide! (\(String(describing: name)))")
        if let placement {
            LogEventManager.shared.log(event: .adShowHide(.admob, placement))
        }
        didHide?()
        self.presentState = false
        self.splashAd = nil
    }
}

extension AdMobSplashAd {
    private func load() {
        guard !isLoading else {
            return
        }
        
        guard let adUnitID else {
            print("[MediationAd] [AdManager] [AdMob] [SplashAd] Failed to load - not initialized yet! Please install ID.")
            didLoadFail?()
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            
            self.isLoading = true
            
            if let timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: { [weak self] in
                    guard let self else {
                        return
                    }
                    guard !didResponse else {
                        return
                    }
                    self.didResponse = true
                    print("[MediationAd] [AdManager] [AdMob] [SplashAd] Load fail (\(String(describing: name))) - timeout!")
                    if let name {
                        LogEventManager.shared.log(event: .adLoadTimeout(.admob, name))
                    }
                    didLoadFail?()
                })
            }
            
            print("[MediationAd] [AdManager] [AdMob] [SplashAd] Start load! (\(String(describing: name)))")
            if let name {
                LogEventManager.shared.log(event: .adLoadRequest(.admob, name))
                TimeManager.shared.start(event: .adLoad(name))
            }
            
            let request = Request()
            InterstitialAd.load(
                with: adUnitID,
                request: request
            ) { [weak self] (ad, error) in
                guard let self else {
                    return
                }
                guard !didResponse else {
                    return
                }
                self.didResponse = true
                guard error == nil, let ad = ad else {
                    print("[MediationAd] [AdManager] [AdMob] [SplashAd] Load fail (\(String(describing: name))) - \(String(describing: error))!")
                    if let name {
                        LogEventManager.shared.log(event: .adLoadFail(.admob, name, error))
                    }
                    self.didLoadFail?()
                    return
                }
                print("[MediationAd] [AdManager] [AdMob] [SplashAd] Did load! (\(String(describing: name)))")
                if let name {
                    let time = TimeManager.shared.end(event: .adLoad(name))
                    LogEventManager.shared.log(event: .adLoadSuccess(.admob, name, time))
                }
                self.splashAd = ad
                self.splashAd?.fullScreenContentDelegate = self
                self.didLoadSuccess?()
                
                let network = ad.responseInfo.adNetworkInfoArray.first
                print("[MediationAd] [AdManager] [AdMob] [SplashAd] Adapter(\(String(describing: network)))!")
                
                ad.paidEventHandler = { adValue in
                    print("[MediationAd] [AdManager] [AdMob] [SplashAd] Did pay revenue(\(adValue.value))!")
                    if let placement = self.placement {
                        LogEventManager.shared.log(event: .adPayRevenue(.admob, placement))
                        if adValue.value == 0 {
                            LogEventManager.shared.log(event: .adNoRevenue(.admob, placement))
                        }
                    }
                    let adRevenueParams: [AnyHashable: Any] = [
                        kAppsFlyerAdRevenueCountry: "US",
                        kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
                        kAppsFlyerAdRevenueAdType: "AdMob_Interstitial_Splash"
                    ]
                    
                    AppsFlyerAdRevenue.shared().logAdRevenue(
                        monetizationNetwork: "admob",
                        mediationNetwork: MediationNetworkType.googleAdMob,
                        eventRevenue: adValue.value,
                        revenueCurrency: adValue.currencyCode,
                        additionalParameters: adRevenueParams)
                }
            }
        }
    }
}
