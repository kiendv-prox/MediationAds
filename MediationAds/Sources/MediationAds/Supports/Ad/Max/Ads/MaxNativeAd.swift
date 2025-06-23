//
//  MaxNativeAd.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 07/08/2024.
//

import UIKit
import AppLovinSDK
import AppsFlyerAdRevenue

class MaxNativeAd: NSObject, OnceUsedAdProtocol {
  enum State {
    case wait
    case loading
    case receive
    case error
  }
  
  private var nativeAd: MAAd?
  private var nativeAdView: MANativeAdView?
  private var adLoader: MANativeAdLoader?
  private weak var rootViewController: UIViewController?
  private var adUnitID: String?
  private var placement: String?
  private var timeout: Double?
  private var state: State = .wait
  private var didReceive: Handler?
  private var didError: Handler?
  
  func config(ad: Native, rootViewController: UIViewController?, into nativeAdView: UIView?) {
    self.rootViewController = rootViewController
    guard ad.status else {
      return
    }
    guard adUnitID == nil else {
      return
    }
    self.adUnitID = ad.id
    self.placement = ad.placement
    self.timeout = ad.timeout
    
    self.nativeAdView = nativeAdView as? MANativeAdView
    let adViewBinder = MANativeAdViewBinder(builderBlock: { builder in
      builder.titleLabelTag = 100
      builder.bodyLabelTag = 101
      builder.callToActionButtonTag = 102
      builder.iconImageViewTag = 103
      builder.mediaContentViewTag = 104
      builder.advertiserLabelTag = 105
    })
    self.nativeAdView?.bindViews(with: adViewBinder)
    self.load()
  }
  
  func getState() -> State {
    return state
  }
  
  func getAd() -> MANativeAd? {
    return nativeAd?.nativeAd
  }
  
  func getAdView() -> MANativeAdView? {
    return nativeAdView
  }
  
  func bind(didReceive: Handler?, didError: Handler?) {
    self.didReceive = didReceive
    self.didError = didError
  }
}

extension MaxNativeAd: MANativeAdDelegate, MAAdRevenueDelegate {
  func didLoadNativeAd(_ nativeAdView: MANativeAdView?, for ad: MAAd) {
    guard state == .loading else {
      return
    }
    print("[MediationAd] [AdManager] [Max] [NativeAd] Did load! (\(String(describing: placement)))")
    if let placement {
      let time = TimeManager.shared.end(event: .adLoad(placement))
      LogEventManager.shared.log(event: .adLoadSuccess(.max, placement, time))
    }
    self.state = .receive
    
    if let currentNativeAd = nativeAd {
      adLoader?.destroy(currentNativeAd)
    }
    self.nativeAd = ad
    
    if let currentNativeAdView = nativeAdView {
      currentNativeAdView.removeFromSuperview()
    }
    self.nativeAdView = nativeAdView
    
    didReceive?()
    
    
    let network = ad.networkName
    print("[MediationAd] [AdManager] [Max] [NativeAd] Adapter(\(String(describing: network)))!")
  }
  
  func didFailToLoadNativeAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
    guard state == .loading else {
      return
    }
    print("[MediationAd] [AdManager] [Max] [NativeAd] Load fail (\(String(describing: placement))) - \(String(describing: error))!")
    if let placement {
      LogEventManager.shared.log(event: .adLoadFail(.max, placement, error as? Error))
    }
    self.state = .error
    didError?()
  }
  
  func didClickNativeAd(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [NativeAd] Did click! (\(String(describing: placement)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowClick(.max, placement))
    }
  }
  
  func didPayRevenue(for ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [NativeAd] Did pay revenue(\(ad.revenue))!")
    if let placement = self.placement {
      LogEventManager.shared.log(event: .adPayRevenue(.max, placement))
      if ad.revenue == 0 {
        LogEventManager.shared.log(event: .adNoRevenue(.max, placement))
      }
    }
    let adRevenueParams: [AnyHashable: Any] = [
      kAppsFlyerAdRevenueCountry: "US",
      kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
      kAppsFlyerAdRevenueAdType: "Max_Native"
    ]
    
    AppsFlyerAdRevenue.shared().logAdRevenue(
      monetizationNetwork: "applovinmax",
      mediationNetwork: MediationNetworkType.applovinMax,
      eventRevenue: ad.revenue as NSNumber,
      revenueCurrency: "USD",
      additionalParameters: adRevenueParams)
  }
}

extension MaxNativeAd {
  private func load() {
    guard state == .wait else {
      return
    }
    
    guard let adUnitID else {
      print("[MediationAd] [AdManager] [Max] [NativeAd] Failed to load - not initialized yet! Please install ID.")
      return
    }
    
    print("[MediationAd] [AdManager] [Max] [NativeAd] Start load! (\(String(describing: placement)))")
    self.state = .loading
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      if let placement {
        LogEventManager.shared.log(event: .adLoadRequest(.max, placement))
        TimeManager.shared.start(event: .adLoad(placement))
      }
      self.adLoader = MANativeAdLoader(adUnitIdentifier: adUnitID)
      adLoader?.setLocalExtraParameterForKey("google_native_ad_view_tag", value: 99)
      adLoader?.nativeAdDelegate = self
      adLoader?.revenueDelegate = self
      adLoader?.loadAd(into: nativeAdView)
    }
    
    if let timeout {
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
        guard let self else {
          return
        }
        guard state == .loading else {
          return
        }
        print("[MediationAd] [AdManager] [Max] [NativeAd] Load fail (\(String(describing: placement))) - time out!")
        if let placement {
          LogEventManager.shared.log(event: .adLoadTimeout(.max, placement))
        }
        self.state = .error
        didError?()
      }
    }
  }
}
