//
//  MaxBannerAdView.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 06/08/2024.
//

import UIKit
import SnapKit
import AppLovinSDK
import AppsFlyerAdRevenue

open class MaxBannerAdView: UIView {
  enum State {
    case wait
    case loading
    case receive
    case error
  }
  
  private weak var rootViewController: UIViewController?
  private var bannerAdView: MAAdView?
  private var adUnitID: String?
  private var placement: String?
  private var state: State = .wait
  private var didReceive: Handler?
  private var didError: Handler?
  
  public override func removeFromSuperview() {
    self.bannerAdView = nil
    super.removeFromSuperview()
  }
  
  public func load(placement: String,
                   rootViewController: UIViewController,
                   didReceive: Handler?,
                   didError: Handler?
  ) {
    self.rootViewController = rootViewController
    self.didReceive = didReceive
    self.didError = didError
    
    guard adUnitID == nil else {
      return
    }
    switch AdManager.shared.status(type: .onceUsed(.banner), placement: placement) {
    case false:
      print("[MediationAd] [AdManager] [Max] [BannerAd] Ads are not allowed to show! (\(String(describing: placement)))")
      errored()
      return
    case true:
      break
    default:
      errored()
      return
    }
    guard let ad = AdManager.shared.getAd(type: .onceUsed(.banner), placement: placement) as? Banner else {
      return
    }
    guard ad.status else {
      return
    }
    self.adUnitID = ad.id
    self.placement = ad.placement
    load()
  }
}

extension MaxBannerAdView: MAAdViewAdDelegate, MAAdRevenueDelegate {
  public func didExpand(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did expand! (\(String(describing: placement)))")
  }
  
  public func didCollapse(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did collapse! (\(String(describing: placement)))")
  }
  
  public func didLoad(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did load! (\(String(describing: placement)))")
    if let placement {
      let time = TimeManager.shared.end(event: .adLoad(placement))
      LogEventManager.shared.log(event: .adLoadSuccess(.admob, placement, time))
    }
    self.state = .receive
    didReceive?()
    
    let network = ad.networkName
    print("[MediationAd] [AdManager] [Max] [BannerAd] Adapter(\(String(describing: network)))!")
  }
  
  public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Load fail (\(String(describing: placement))) - \(String(describing: error))!")
    if let placement {
      LogEventManager.shared.log(event: .adLoadFail(.max, placement, error as? Error))
    }
    self.state = .error
    errored()
  }
  
  public func didDisplay(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did display! (\(String(describing: placement)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowSuccess(.max, placement))
    }
  }
  
  public func didHide(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did hide! (\(String(describing: placement)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowHide(.max, placement))
    }
  }
  
  public func didClick(_ ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did click! (\(String(describing: placement)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowClick(.max, placement))
    }
  }
  
  public func didFail(toDisplay ad: MAAd, withError error: MAError) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did fail to show content! (\(String(describing: placement)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowFail(.max, placement, error as? Error))
    }
  }
  
  public func didPayRevenue(for ad: MAAd) {
    print("[MediationAd] [AdManager] [Max] [BannerAd] Did pay revenue(\(ad.revenue))!")
    if let placement = self.placement {
      LogEventManager.shared.log(event: .adPayRevenue(.max, placement))
      if ad.revenue == 0 {
        LogEventManager.shared.log(event: .adNoRevenue(.max, placement))
      }
    }
    let adRevenueParams: [AnyHashable: Any] = [
      kAppsFlyerAdRevenueCountry: "US",
      kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
      kAppsFlyerAdRevenueAdType: "Max_Banner"
    ]
    
    AppsFlyerAdRevenue.shared().logAdRevenue(
      monetizationNetwork: "applovinmax",
      mediationNetwork: MediationNetworkType.applovinMax,
      eventRevenue: ad.revenue as NSNumber,
      revenueCurrency: "USD",
      additionalParameters: adRevenueParams)
  }
}

extension MaxBannerAdView {
  func addComponents() {
    guard let adUnitID,
      bannerAdView == nil else {
      return
    }
    let bannerAdView = MAAdView(adUnitIdentifier: adUnitID)
    self.bannerAdView = bannerAdView
    bannerAdView.frame.size = frame.size
    addSubview(bannerAdView)
    setConstraints()
  }
  
  func setConstraints() {
    bannerAdView?.snp.makeConstraints({ make in
      make.edges.equalToSuperview()
    })
  }
  
  private func errored() {
    didError?()
  }
  
  private func load() {
    guard state == .wait else {
      return
    }
    
    guard adUnitID != nil else {
      print("[MediationAd] [AdManager] [Max] [BannerAd] Failed to load - not initialized yet! Please install ID.")
      return
    }
    
    print("[MediationAd] [AdManager] [Max] [BannerAd] Start load! (\(String(describing: placement)))")
    self.state = .loading
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      addComponents()
//      setConstraints()
      bannerAdView?.delegate = self
      bannerAdView?.revenueDelegate = self
      bannerAdView?.stopAutoRefresh()
      bannerAdView?.setExtraParameterForKey("adaptive_banner", value: "true")
      if let placement {
        LogEventManager.shared.log(event: .adLoadRequest(.max, placement))
        TimeManager.shared.start(event: .adLoad(placement))
      }
      bannerAdView?.loadAd()
    }
  }
}
