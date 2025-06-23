//
//  InterstitialAd.swift
//  AdManager
//
//  Created by Trịnh Xuân Minh on 25/03/2022.
//

import UIKit
import GoogleMobileAds
import AppsFlyerAdRevenue

class AdMobInterstitialAd: NSObject, ReuseAdProtocol {
    private var interstitialAd: InterstitialAd?
    private var adUnitID: String?
    private var placement: String?
    private var name: String?
    private var presentState = false
    private var isLoading = false
    private var retryAttempt = 0
    private var didLoadFail: Handler?
    private var didLoadSuccess: Handler?
    private var didShowFail: Handler?
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
    
    func isPresent() -> Bool {
        return presentState
    }
    
    func isExist() -> Bool {
        return interstitialAd != nil
    }
    
    func show(placement: String,
              rootViewController: UIViewController,
              didFail: Handler?,
              willPresent: Handler?,
              didEarnReward: Handler?,
              didHide: Handler?
    ) {
        guard !presentState else {
            print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Display failure - ads are being displayed! (\(placement))")
            didFail?()
            return
        }
        LogEventManager.shared.log(event: .adShowRequest(.admob, placement))
        guard isReady() else {
            print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Display failure - not ready to show! (\(placement))")
            LogEventManager.shared.log(event: .adShowNoReady(.admob, placement))
            didFail?()
            return
        }
        LogEventManager.shared.log(event: .adShowReady(.admob, placement))
        print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Requested to show! (\(placement))")
        self.placement = placement
        self.didShowFail = didFail
        self.willPresent = willPresent
        self.didHide = didHide
        self.didEarnReward = didEarnReward
        interstitialAd?.present(from: rootViewController)
    }
}

extension AdMobInterstitialAd: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Did fail to show content! (\(String(describing: name)))")
        if let placement {
            LogEventManager.shared.log(event: .adShowFail(.admob, placement, error))
        }
        didShowFail?()
        self.interstitialAd = nil
        load()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Will display! (\(String(describing: name)))")
        if let placement {
            LogEventManager.shared.log(event: .adShowSuccess(.admob, placement))
        }
        willPresent?()
        self.presentState = true
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Did hide! (\(String(describing: name)))")
        if let placement {
            LogEventManager.shared.log(event: .adShowHide(.admob, placement))
        }
        didHide?()
        self.interstitialAd = nil
        self.presentState = false
        load()
    }
}

extension AdMobInterstitialAd {
    private func isReady() -> Bool {
        if !isExist(), retryAttempt >= 1 {
            load()
        }
        return isExist()
    }
    
    private func load() {
        guard !isLoading else {
            return
        }
        
        guard !isExist() else {
            return
        }
        
        guard let adUnitID else {
            print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Failed to load - not initialized yet! Please install ID.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            
            self.isLoading = true
            print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Start load! (\(String(describing: name)))")
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
                self.isLoading = false
                guard error == nil, let ad = ad else {
                    print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Load fail (\(String(describing: name))) - \(String(describing: error))!")
                    self.retryAttempt += 1
                    if let name {
                        LogEventManager.shared.log(event: .adLoadFail(.admob, name, error))
                    }
                    self.didLoadFail?()
                    return
                }
                print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Did load! (\(String(describing: name)))")
                if let name {
                    let time = TimeManager.shared.end(event: .adLoad(name))
                    LogEventManager.shared.log(event: .adLoadSuccess(.admob, name, time))
                }
                self.retryAttempt = 0
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                self.didLoadSuccess?()
                
                let network = ad.responseInfo.adNetworkInfoArray.first
                print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Adapter(\(String(describing: network)))!")
                
                ad.paidEventHandler = { adValue in
                    print("[MediationAd] [AdManager] [AdMob] [InterstitialAd] Did pay revenue(\(adValue.value))!")
                    if let placement = self.placement {
                        LogEventManager.shared.log(event: .adPayRevenue(.admob, placement))
                        if adValue.value == 0 {
                            LogEventManager.shared.log(event: .adNoRevenue(.admob, placement))
                        }
                    }
                    let adRevenueParams: [AnyHashable: Any] = [
                        kAppsFlyerAdRevenueCountry: "US",
                        kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
                        kAppsFlyerAdRevenueAdType: "AdMob_Interstitial"
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
