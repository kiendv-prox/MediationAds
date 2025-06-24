//
//  AdManager.swift
//  AdManager
//
//  Created by Trịnh Xuân Minh on 25/03/2022.
//

import UIKit

public class AdManager {
  public static var shared = AdManager()
  
  enum Keys {
    static let cache = "AD_CACHE"
  }
  
  enum Resource: String {
    case remote
    case cache
    case local
  }
  
  public enum State: String {
    case wait
    case success
    case premium
    case reject
    case error
  }
  
  public enum OnceUsed {
    case native
    case banner
  }
  
  public enum Reuse {
    case splash
    case appOpen
    case interstitial
    case rewarded
    case rewardedInterstitial
  }
  
  public enum AdType {
    case onceUsed(_ type: OnceUsed)
    case reuse(_ type: Reuse)
  }
  
  @Published public private(set) var registerState: State = .wait
  private var isPremium = false
  private var isRelease = true
  private var isConsent = true
  private var defaultData: Data?
  private var adConfig: AdConfig?
  private(set) weak var rootViewController: UIViewController?
  private var listReuseAd: [String: ReuseAdProtocol] = [:]
  private var listNativeAd: [String: OnceUsedAdProtocol] = [:]
  
  public func upgradePremium() {
    guard !isPremium else {
      return
    }
    print("[MediationAd] [AdManager] Upgrade premium!")
    self.isPremium = true
  }
  
  public func upgradeConsent() {
    guard !isConsent else {
      return
    }
    print("[MediationAd] [AdManager] Upgrade consent!")
    self.isConsent = true
    self.registerState = .success
  }
  
  public func register(isRelease: Bool,
                       isConsent: Bool,
                       defaultData: Data,
                       remoteData: Data
  ) {
    guard registerState == .wait else {
      return
    }
    self.defaultData = defaultData
    self.isRelease = isRelease
    self.isConsent = isConsent
    
    guard !isPremium else {
      print("[MediationAd] [AdManager] Premium!")
      change(state: .premium)
      return
    }
    
    print("[MediationAd] [AdManager] Start register!")
    LogEventManager.shared.log(event: .adManagerStartRegister)
    
    decoding(data: remoteData, resource: .remote)
    fetchCache()
    fetchDefault()
  }
  
  public func status(type: AdType, placement: String) -> Bool? {
    guard !isPremium else {
      print("[MediationAd] [AdManager] Premium!")
      return nil
    }
    guard let adConfig else {
      print("[MediationAd] [AdManager] Not yet registered!")
      return nil
    }
    guard adConfig.status else {
      return false
    }
    guard registerState == .success else {
      print("[MediationAd] [AdManager] Can't Request Ads!")
      return nil
    }
    guard let config = getAd(type: type, placement: placement) as? AdConfigProtocol else {
      print("[MediationAd] [AdManager] Ads don't exist! (\(placement))")
      return nil
    }
    if !isRelease, config.isAuto == true {
      return false
    }
    return config.status
  }
  
  public func network(type: AdType, placement: String) -> MonetizationNetwork? {
    guard let adConfig = getAd(type: type, placement: placement) as? AdConfigProtocol else {
      print("[MediationAd] [AdManager] Ads don't exist! (\(placement))")
      return nil
    }
    return adConfig.network
  }
  
  public func load(type: Reuse,
                   placement: String,
                   success: Handler? = nil,
                   fail: Handler? = nil
  ) {
    switch status(type: .reuse(type), placement: placement) {
    case false:
      print("[MediationAd] [AdManager] Ads are not allowed to show! (\(placement))")
      fail?()
      return
    case true:
      break
    default:
      fail?()
      return
    }
    guard let adConfig = getAd(type: .reuse(type), placement: placement) as? AdConfigProtocol else {
      print("[MediationAd] [AdManager] Ads don't exist! (\(placement))")
      fail?()
      return
    }
    guard listReuseAd[adConfig.name] == nil else {
      fail?()
      return
    }
    
    let adProtocol: ReuseAdProtocol!
    
    switch adConfig.network {
    case .admob:
      switch type {
      case .splash:
        guard let splash = adConfig as? Splash else {
          print("[MediationAd] [AdManager] Format conversion error! (\(placement))")
          fail?()
          return
        }
        let splashAd = AdMobSplashAd()
        splashAd.config(timeout: splash.timeout)
        adProtocol = splashAd
      case .appOpen:
        adProtocol = AdMobAppOpenAd()
      case .interstitial:
        adProtocol = AdMobInterstitialAd()
      case .rewarded:
        adProtocol = AdMobRewardedAd()
      case .rewardedInterstitial:
        adProtocol = AdMobRewardedInterstitialAd()
      }
    case .max:
      switch type {
      case .splash:
        guard let splash = adConfig as? Splash else {
          print("[MediationAd] [AdManager] Format conversion error! (\(placement))")
          fail?()
          return
        }
        let splashAd = MaxSplashAd()
        splashAd.config(timeout: splash.timeout)
        adProtocol = splashAd
      case .appOpen:
        adProtocol = MaxAppOpenAd()
      case .interstitial:
        adProtocol = MaxInterstitialAd()
      case .rewarded:
        adProtocol = MaxRewardedAd()
      case .rewardedInterstitial:
        print("[MediationAd] [AdManager] This type of ads is not supported! (\(placement))")
        fail?()
        return
      }
    }
    
    adProtocol.config(didFail: fail, didSuccess: success)
    adProtocol.config(id: adConfig.id, name: adConfig.name)
    self.listReuseAd[adConfig.name] = adProtocol
  }
  
  public func isReady(type: Reuse, placement: String) -> Bool {
    switch status(type: .reuse(type), placement: placement) {
    case false:
      print("[AdMobManager] Ads are not allowed to show! (\(placement))")
      return false
    case true:
      break
    default:
      return false
    }
    guard let adConfig = getAd(type: .reuse(type), placement: placement) as? AdConfigProtocol else {
      print("[AdMobManager] Ads don't exist! (\(placement))")
      return false
    }
    guard let ad = listReuseAd[adConfig.name] else {
      print("[AdMobManager] Ads do not exist! (\(placement))")
      return false
    }
    guard !checkIsPresent() else {
      print("[AdMobManager] Ads display failure - other ads is showing! (\(placement))")
      return false
    }
    guard checkFrequency(adConfig: adConfig, ad: ad) else {
      print("[AdMobManager] Ads hasn't been displayed yet! (\(placement))")
      return false
    }
    return true
  }
  
  public func preloadNative(placement: String,
                            into nativeAdView: UIView? = nil,
                            success: Handler? = nil,
                            fail: Handler? = nil
  ) {
    switch status(type: .onceUsed(.native), placement: placement) {
    case false:
      print("[MediationAd] [AdManager] Ads are not allowed to show! (\(placement))")
      fail?()
      return
    case true:
      break
    default:
      fail?()
      return
    }
    guard let native = getAd(type: .onceUsed(.native), placement: placement) as? Native else {
      print("[MediationAd] [AdManager] Ads don't exist! (\(placement))")
      fail?()
      return
    }
    guard native.isPreload == true else {
      print("[MediationAd] [AdManager] Ads are not preloaded! (\(placement))")
      fail?()
      return
    }
    guard listNativeAd[placement] == nil else {
      fail?()
      return
    }
    let nativeAd: OnceUsedAdProtocol!
    
    switch native.network {
    case .admob:
      nativeAd = AdMobNativeAd()
    case .max:
      nativeAd = MaxNativeAd()
    }
    
    nativeAd.bind(didReceive: success, didError: fail)
    nativeAd.config(ad: native,
                    rootViewController: nil,
                    into: nativeAdView)
    
    self.listNativeAd[placement] = nativeAd
  }
  
  public func show(type: Reuse,
                   placement: String,
                   rootViewController: UIViewController,
                   didFail: Handler?,
                   willPresent: Handler? = nil,
                   didEarnReward: Handler? = nil,
                   didHide: Handler?
  ) {
    self.rootViewController = rootViewController
    switch status(type: .reuse(type), placement: placement) {
    case false:
      print("[MediationAd] [AdManager] Ads are not allowed to show! (\(placement))")
      didFail?()
      return
    case true:
      break
    default:
      didFail?()
      return
    }
    guard let adConfig = getAd(type: .reuse(type), placement: placement) as? AdConfigProtocol else {
      print("[MediationAd] [AdManager] Ads don't exist! (\(placement))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowCheck(adConfig.network, adConfig.placement))
    guard let ad = listReuseAd[adConfig.name] else {
      print("[MediationAd] [AdManager] Ads do not exist! (\(placement))")
      didFail?()
      return
    }
    guard !checkIsPresent() else {
      print("[MediationAd] [AdManager] Ads display failure - other ads is showing! (\(placement))")
      didFail?()
      return
    }
    guard checkFrequency(adConfig: adConfig, ad: ad) else {
      print("[MediationAd] [AdManager] Ads hasn't been displayed yet! (\(placement))")
      didFail?()
      return
    }
    ad.show(placement: adConfig.placement,
            rootViewController: rootViewController,
            didFail: didFail,
            willPresent: willPresent,
            didEarnReward: didEarnReward,
            didHide: didHide)
  }
}

extension AdManager {
  func getAd(type: AdType, placement: String) -> Any? {
    guard let adConfig else {
      return nil
    }
    switch type {
    case .onceUsed(let type):
      switch type {
      case .banner:
        return adConfig.banners?.first(where: { $0.placement == placement })
      case .native:
        return adConfig.natives?.first(where: { $0.placement == placement })
      }
    case .reuse(let type):
      switch type {
      case .splash:
        return adConfig.splashs?.first(where: { $0.placement == placement })
      case .appOpen:
        return adConfig.appOpens?.first(where: { $0.placement == placement })
      case .interstitial:
        return adConfig.interstitials?.first(where: { $0.placement == placement })
      case .rewarded:
        return adConfig.rewardeds?.first(where: { $0.placement == placement })
      case .rewardedInterstitial:
        return adConfig.rewardedInterstitials?.first(where: { $0.placement == placement })
      }
    }
  }
  
  func getNativePreload(placement: String) -> OnceUsedAdProtocol? {
    return listNativeAd[placement]
  }
}

extension AdManager {
  private func checkIsPresent() -> Bool {
    for ad in listReuseAd where ad.value.isPresent() {
      return true
    }
    return false
  }
  
  private func updateCache() {
    guard let adConfig else {
      return
    }
    guard let data = try? JSONEncoder().encode(adConfig) else {
      return
    }
    UserDefaults.standard.set(data, forKey: Keys.cache)
  }
  
  private func decoding(data: Data, resource: Resource) {
    guard registerState == .wait else {
      return
    }
    guard let adConfig = try? JSONDecoder().decode(AdConfig.self, from: data) else {
      print("[MediationAd] [AdManager] Invalid (AdMobConfig) format - \(resource.rawValue.capitalized)!")
      switch resource {
      case .remote:
        LogEventManager.shared.log(event: .adManagerRemoteInvaidFormat)
      case .cache:
        LogEventManager.shared.log(event: .adManagerLocalInvaidFormat)
      case .local:
        LogEventManager.shared.log(event: .adManagerCacheInvaidFormat)
      }
      return
    }
    
    self.adConfig = adConfig
    updateCache()
    
    if isConsent {
      change(state: .success)
    } else {
      change(state: .reject)
    }
  }
  
  private func fetchCache() {
    guard let cacheData = UserDefaults.standard.data(forKey: Keys.cache) else {
      return
    }
    decoding(data: cacheData, resource: .cache)
  }
  
  private func fetchDefault() {
    guard let defaultData else {
      return
    }
    decoding(data: defaultData, resource: .local)
    change(state: .error)
  }
  
  private func checkFrequency(adConfig: AdConfigProtocol, ad: ReuseAdProtocol) -> Bool {
    guard
      let interstitial = adConfig as? Interstitial,
      let start = interstitial.start,
      let frequency = interstitial.frequency
    else {
      return true
    }
    let countClick = FrequencyManager.shared.getCount(placement: adConfig.placement) + 1
    guard countClick >= start else {
      FrequencyManager.shared.increaseCount(placement: adConfig.placement)
      return false
    }
    let isShow = (countClick - start) % frequency == 0
    if !isShow || ad.isExist() {
      FrequencyManager.shared.increaseCount(placement: adConfig.placement)
    }
    return isShow
  }
  
  private func change(state: State) {
    guard registerState == .wait else {
      return
    }
    print("[MediationAd] [AdManager] register \(state)!")
    self.registerState = state
    
    switch state {
    case .success:
      LogEventManager.shared.log(event: .adManagerSuccess)
    case .premium:
      LogEventManager.shared.log(event: .adManagerPremium)
    case .reject:
      LogEventManager.shared.log(event: .adManagerReject)
    case .error:
      LogEventManager.shared.log(event: .adManagerError)
    default:
      break
    }
  }
}
