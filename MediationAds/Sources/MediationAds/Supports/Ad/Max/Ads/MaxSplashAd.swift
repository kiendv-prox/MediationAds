//
//  MaxSplashAd.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 06/08/2024.
//

import UIKit
import AppLovinSDK
import AppsFlyerAdRevenue

class MaxSplashAd: NSObject, ReuseAdProtocol {
  private var splashAd: MAInterstitialAd?
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
      print("[MediationAd] [AdManager] [Max] [SplashAd] Display failure - ads are being displayed! (\(placement))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowRequest(.max, placement))
    guard isExist() else {
      print("[MediationAd] [AdManager] [Max] [SplashAd] Display failure - not ready to show! (\(placement))")
      LogEventManager.shared.log(event: .adShowNoReady(.max, placement))
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowReady(.max, placement))
    print("[MediationAd] [AdManager] [Max] [SplashAd] Requested to show! (\(placement))")
    self.placement = placement
    self.didFail = didFail
    self.willPresent = willPresent
    self.didHide = didHide
    self.didEarnReward = didEarnReward
    splashAd?.show()
  }
}

extension MaxSplashAd: MAAdDelegate, MAAdRevenueDelegate {
  func didLoad(_ ad: MAAd) {
    guard !didResponse else {
      return
    }
    self.didResponse = true
    print("[MediationAd] [AdManager] [Max] [SplashAd] Did load! (\(String(describing: name)))")
    if let name {
      let time = TimeManager.shared.end(event: .adLoad(name))
      LogEventManager.shared.log(event: .adLoadSuccess(.max, name, time))
    }
    self.didLoadSuccess?()
    
    let network = ad.networkName
    print("[MediationAd] [AdManager] [Max] [SplashAd] Adapter(\(String(describing: network)))!")
  }
  
  func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
    guard !didResponse else {
      return
    }
    self.didResponse = true
    print("[MediationAd] [AdManager] [Max] [SplashAd] Load fail (\(String(describing: name))) - \(String(describing: error))!")
    if let name {
      LogEventManager.shared.log(event: .adLoadFail(.max, name, error as? Error))
    }
    self.didLoadFail?()
  }
  
  func didDisplay(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [SplashAd] Will display! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowSuccess(.max, placement))
    }
    willPresent?()
    self.presentState = true
  }
  
  func didClick(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [SplashAd] Did click! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowClick(.max, placement))
    }
  }
  
  func didFail(toDisplay ad: MAAd, withError error: MAError) {
    print("[MediationAd] [AdManager] [Max] [SplashAd] Did fail to show content! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowFail(.max, placement, error as? Error))
    }
    didFail?()
    self.splashAd = nil
  }
  
  func didHide(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [SplashAd] Did hide! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowHide(.max, placement))
    }
    didHide?()
    self.presentState = false
    self.splashAd = nil
  }
  
  func didPayRevenue(for ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [SplashAd] Did pay revenue(\(ad.revenue))!")
    if let placement = self.placement {
      LogEventManager.shared.log(event: .adPayRevenue(.max, placement))
      if ad.revenue == 0 {
        LogEventManager.shared.log(event: .adNoRevenue(.max, placement))
      }
    }
    let adRevenueParams: [AnyHashable: Any] = [
      kAppsFlyerAdRevenueCountry: "US",
      kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
      kAppsFlyerAdRevenueAdType: "Max_Interstitial_Splash"
    ]
    
    AppsFlyerAdRevenue.shared().logAdRevenue(
      monetizationNetwork: "applovinmax",
      mediationNetwork: MediationNetworkType.applovinMax,
      eventRevenue: ad.revenue as NSNumber,
      revenueCurrency: "USD",
      additionalParameters: adRevenueParams)
  }
}

extension MaxSplashAd {
  private func load() {
    guard !isLoading else {
      return
    }
    
    guard let adUnitID else {
      print("[MediationAd] [AdManager] [Max] [SplashAd] Failed to load - not initialized yet! Please install ID.")
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
          print("[MediationAd] [AdManager] [Max] [SplashAd] Load fail (\(String(describing: name))) - timeout!")
          if let name {
            LogEventManager.shared.log(event: .adLoadTimeout(.max, name))
          }
          didLoadFail?()
        })
      }
      
      print("[MediationAd] [AdManager] [Max] [SplashAd] Start load! (\(String(describing: name)))")
      if let name {
        LogEventManager.shared.log(event: .adLoadRequest(.max, name))
        TimeManager.shared.start(event: .adLoad(name))
      }
      
      self.splashAd = MAInterstitialAd(adUnitIdentifier: adUnitID)
      splashAd?.delegate = self
      splashAd?.revenueDelegate = self
      splashAd?.load()
    }
  }
}
