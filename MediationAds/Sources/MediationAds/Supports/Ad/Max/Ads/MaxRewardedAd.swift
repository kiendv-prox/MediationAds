//
//  MaxRewardedAd.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 06/08/2024.
//

import UIKit
import AppLovinSDK
import AppsFlyerAdRevenue

class MaxRewardedAd: NSObject, ReuseAdProtocol {
  private var rewardedAd: MARewardedAd?
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
    return rewardedAd != nil
  }
  
  func show(placement: String,
            rootViewController: UIViewController,
            didFail: Handler?,
            willPresent: Handler?,
            didEarnReward: Handler?,
            didHide: Handler?
  ) {
    guard !presentState else {
      print("[MediationAd] [AdManager] [Max] [RewardAd] Display failure - ads are being displayed! (\(placement))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowRequest(.max, placement))
    guard isReady() else {
      print("[MediationAd] [AdManager] [Max] [RewardAd] Display failure - not ready to show! (\(placement))")
      LogEventManager.shared.log(event: .adShowNoReady(.max, placement))
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowReady(.max, placement))
    print("[MediationAd] [AdManager] [Max] [RewardAd] Requested to show! (\(placement))")
    self.placement = placement
    self.didShowFail = didFail
    self.willPresent = willPresent
    self.didHide = didHide
    self.didEarnReward = didEarnReward
    rewardedAd?.show()
  }
}

extension MaxRewardedAd: MARewardedAdDelegate, MAAdRevenueDelegate {
  func didLoad(_ ad: MAAd) {
    self.isLoading = false
    print("[MediationAd] [AdManager] [Max] [RewardAd] Did load! (\(String(describing: name)))")
    if let name {
      let time = TimeManager.shared.end(event: .adLoad(name))
      LogEventManager.shared.log(event: .adLoadSuccess(.max, name, time))
    }
    self.retryAttempt = 0
    self.didLoadSuccess?()
    
    let network = ad.networkName
    print("[MediationAd] [AdManager] [Max] [RewardAd] Adapter(\(String(describing: network)))!")
  }
  
  func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
    print("[MediationAd] [AdManager] [Max] [RewardAd] Load fail (\(String(describing: name))) - \(String(describing: error))!")
    self.isLoading = false
    self.retryAttempt += 1
    if let name {
      LogEventManager.shared.log(event: .adLoadFail(.max, name, error as? Error))
    }
    self.didLoadFail?()
  }
  
  func didDisplay(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [RewardAd] Will display! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowSuccess(.max, placement))
    }
    willPresent?()
    self.presentState = true
  }
  
  func didClick(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [RewardAd] Did click! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowClick(.max, placement))
    }
  }
  
  func didFail(toDisplay ad: MAAd, withError error: MAError) {
    print("[MediationAd] [AdManager] [Max] [RewardAd] Did fail to show content! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowFail(.max, placement, error as? Error))
    }
    didShowFail?()
    self.rewardedAd = nil
    load()
  }
  
  func didRewardUser(for ad: MAAd, with reward: MAReward) {
    print("[MediationAd] [AdManager] [Max] [RewardAd] Did reward user! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adEarnReward(.max, placement))
    }
    didEarnReward?()
  }
  
  func didHide(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [RewardAd] Did hide! (\(String(describing: name)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowHide(.max, placement))
    }
    didHide?()
    self.rewardedAd = nil
    self.presentState = false
    load()
  }
  
  func didPayRevenue(for ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [RewardAd] Did pay revenue(\(ad.revenue))!")
    if let placement = self.placement {
      LogEventManager.shared.log(event: .adPayRevenue(.max, placement))
      if ad.revenue == 0 {
        LogEventManager.shared.log(event: .adNoRevenue(.max, placement))
      }
    }
    let adRevenueParams: [AnyHashable: Any] = [
      kAppsFlyerAdRevenueCountry: "US",
      kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
      kAppsFlyerAdRevenueAdType: "Max_Rewarded"
    ]
    
    AppsFlyerAdRevenue.shared().logAdRevenue(
      monetizationNetwork: "applovinmax",
      mediationNetwork: MediationNetworkType.applovinMax,
      eventRevenue: ad.revenue as NSNumber,
      revenueCurrency: "USD",
      additionalParameters: adRevenueParams)
  }
}

extension MaxRewardedAd {
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
      print("[MediationAd] [AdManager] [Max] [RewardAd] Failed to load - not initialized yet! Please install ID.")
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      
      self.isLoading = true
      print("[MediationAd] [AdManager] [Max] [RewardAd] Start load! (\(String(describing: name)))")
      if let name {
        LogEventManager.shared.log(event: .adLoadRequest(.max, name))
        TimeManager.shared.start(event: .adLoad(name))
      }
      
      self.rewardedAd = MARewardedAd.shared(withAdUnitIdentifier: adUnitID)
      rewardedAd?.delegate = self
      rewardedAd?.revenueDelegate = self
      rewardedAd?.load()
    }
  }
}
