//
//  LogEventManager.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 02/08/2024.
//

import Foundation
import FirebaseAnalytics

class LogEventManager {
  static let shared = LogEventManager()
  
  private var isWarning = false
  
  func log(event: Event) {
#if DEBUG
    guard AppManager.shared.debugLogEvent else {
      return
    }
    print("[MediationAd] [LogEventManager]", "[\(isValid(event.name, limit: 40))]", event.name, event.parameters ?? String())
    if !isValid(event.name, limit: 40) {
      showWarning()
    }
#endif
    
#if !DEBUG
    Analytics.logEvent(event.name, parameters: event.parameters)
#endif
  }
  
  func checkFormat(adConfig: AdConfig) {
    let maxCharacter = 20
    
    let body: ((AdConfigProtocol) -> Void) = { [weak self] ad in
      guard let self else {
        return
      }
      if !isValid(ad.placement, limit: maxCharacter) || !isValid(ad.name, limit: maxCharacter) {
        showWarning()
        return
      }
    }
    
    adConfig.splashs?.forEach(body)
    adConfig.appOpens?.forEach(body)
    adConfig.interstitials?.forEach(body)
    adConfig.rewardeds?.forEach(body)
    adConfig.rewardedInterstitials?.forEach(body)
    adConfig.banners?.forEach(body)
    adConfig.natives?.forEach(body)
  }
}

extension LogEventManager {
  private func isValid(_ input: String, limit: Int) -> Bool {
    guard input.count <= limit else {
      return false
    }
    let pattern = "^[a-zA-Z0-9_]*$"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: input.utf16.count)
    return regex.firstMatch(in: input, options: [], range: range) != nil
  }
  
  private func showWarning() {
    guard !isWarning else {
      return
    }
    self.isWarning = true
    
    guard let topVC = UIApplication.topViewController() else {
      return
    }
    let alert = UIAlertController(title: "Error", message: "Missing event", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
      guard let self else {
        return
      }
      self.isWarning = false
    }))
    topVC.present(alert, animated: true)
  }
}

enum Event {
  case appManagerStartSession
  case appManagerStartConfig
  case appManagerSuccess(Double)
  case appManagerTimeout
  
  case remoteManagerStartLoad
  case remoteManagerSuccess(Double)
  case remoteManagerError(Double)
  case remoteManagerTimeout
  
  case releaseManagerStartCheck
  case releaseManagerWaitReview(Double)
  case releaseManagerLive(Double)
  case releaseManagerError(Double)
  case releaseManagerTimeout
  
  case consentManagerUseCache
  case consentManagerInvalidFormat
  case consentManagerStartCheck
  case consentManagerNotRequest
  case consentManagerRequest
  case consentManagerTimeout
  case consentManagerInfoError
  case consentManagerFormError
  case consentManagerAgree(Double)
  case consentManagerReject(Double)
  case consentManagerError(Double)
  case consentManagerAutoAgree
  case consentManagerAutoAgreeGDPR
  case consentManagerUpdateRequest
  case consentManagerUpdateAgree
  case consentManagerUpdateReject
  case consentManagerUpdateError
  
  case trackingManagerConnected
  case trackingManagerNoConnect
  case trackingManagerAgree
  case trackingManagerReject
  
  case adManagerStartRegister
  case adManagerRemoteInvaidFormat
  case adManagerCacheInvaidFormat
  case adManagerLocalInvaidFormat
  case adManagerSuccess
  case adManagerPremium
  case adManagerReject
  case adManagerError
  
  case adLoadRequest(MonetizationNetwork, String)
  case adLoadSuccess(MonetizationNetwork, String, Double)
  case adLoadFail(MonetizationNetwork, String, Error?)
  case adLoadTimeout(MonetizationNetwork, String)
  case adShowCheck(MonetizationNetwork, String, UIViewController? = nil)
  case adShowRequest(MonetizationNetwork, String, UIViewController? = nil)
  case adShowReady(MonetizationNetwork, String, UIViewController? = nil)
  case adShowNoReady(MonetizationNetwork, String, UIViewController? = nil)
  case adShowSuccess(MonetizationNetwork, String, UIViewController? = nil)
  case adShowFail(MonetizationNetwork, String, Error?, UIViewController? = nil)
  case adShowHide(MonetizationNetwork, String, UIViewController? = nil)
  case adShowClick(MonetizationNetwork, String, UIViewController? = nil)
  case adEarnReward(MonetizationNetwork, String, UIViewController? = nil)
  case adPayRevenue(MonetizationNetwork, String, UIViewController? = nil)
  case adNoRevenue(MonetizationNetwork, String, UIViewController? = nil)
  
  var name: String {
    switch self {
    case .appManagerStartSession:
      return "AppManager_Start_Session"
    case .appManagerStartConfig:
      return "AppManager_Start_Config"
    case .appManagerSuccess:
      return "AppManager_Success"
    case .appManagerTimeout:
      return "AppManager_Timeout"
      
    case .remoteManagerStartLoad:
      return "RemoteManager_Start_Load"
    case .remoteManagerTimeout:
      return "RemoteManager_Timeout"
    case .remoteManagerSuccess:
      return "RemoteManager_Success"
    case .remoteManagerError:
      return "RemoteManager_Error"
      
    case .releaseManagerStartCheck:
      return "ReleaseManager_Start_Check"
    case .releaseManagerWaitReview:
      return "ReleaseManager_WaitReview"
    case .releaseManagerLive:
      return "ReleaseManager_Live"
    case .releaseManagerError:
      return "ReleaseManager_Error"
    case .releaseManagerTimeout:
      return "ReleaseManager_Timeout"
      
    case .consentManagerUseCache:
      return "ConsentManager_Use_Cache"
    case .consentManagerInvalidFormat:
      return "ConsentManager_Invalid_Format"
    case .consentManagerStartCheck:
      return "ConsentManager_Start_Check"
    case .consentManagerNotRequest:
      return "ConsentManager_Not_Request"
    case .consentManagerRequest:
      return "ConsentManager_Request"
    case .consentManagerTimeout:
      return "ConsentManager_Timeout"
    case .consentManagerInfoError:
      return "ConsentManager_Info_Error"
    case .consentManagerFormError:
      return "ConsentManager_Form_Error"
    case .consentManagerAgree:
      return "ConsentManager_Agree"
    case .consentManagerReject:
      return "ConsentManager_Reject"
    case .consentManagerError:
      return "ConsentManager_Error"
    case .consentManagerAutoAgree:
      return "ConsentManager_Auto_Agree"
    case .consentManagerAutoAgreeGDPR:
      return "ConsentManager_Auto_Agree_GDPR"
    case .consentManagerUpdateRequest:
      return "ConsentManager_Update_Request"
    case .consentManagerUpdateAgree:
      return "ConsentManager_Update_Agree"
    case .consentManagerUpdateReject:
      return "ConsentManager_Update_Reject"
    case .consentManagerUpdateError:
      return "ConsentManager_Update_Error"
      
    case .trackingManagerConnected:
      return "TrackingManager_Connected"
    case .trackingManagerNoConnect:
      return "TrackingManager_No_Connect"
    case .trackingManagerAgree:
      return "TrackingManager_Agree"
    case .trackingManagerReject:
      return "TrackingManager_Reject"
      
    case .adManagerStartRegister:
      return "AdManager_Start_Register"
    case .adManagerRemoteInvaidFormat:
      return "AdManager_Remote_Invaid_Format"
    case .adManagerCacheInvaidFormat:
      return "AdManager_Cache_Invaid_Format"
    case .adManagerLocalInvaidFormat:
      return "AdManager_Local_Invaid_Format"
    case .adManagerSuccess:
      return "AdManager_Success"
    case .adManagerPremium:
      return "AdManager_Premium"
    case .adManagerReject:
      return "AdManager_Reject"
    case .adManagerError:
      return "AdManager_Error"
      
    case .adLoadRequest(let network, let id):
      return "\(network.name)_\(id)_Load_Request"
    case .adLoadSuccess(let network, let id, _):
      return "\(network.name)_\(id)_Load_Success"
    case .adLoadFail(let network, let id, _):
      return "\(network.name)_\(id)_Load_Fail"
    case .adLoadTimeout(let network, let id):
      return "\(network.name)_\(id)_Load_Timeout"
    case .adShowCheck(let network, let id, _):
      return "\(network.name)_\(id)_Show_Check"
    case .adShowRequest(let network, let id, _):
      return "\(network.name)_\(id)_Show_Request"
    case .adShowReady(let network, let id, _):
      return "\(network.name)_\(id)_Show_Ready"
    case .adShowNoReady(let network, let id, _):
      return "\(network.name)_\(id)_Show_NoReady"
    case .adShowSuccess(let network, let id, _):
      return "\(network.name)_\(id)_Show_Success"
    case .adShowFail(let network, let id, _, _):
      return "\(network.name)_\(id)_Show_Fail"
    case .adShowHide(let network, let id, _):
      return "\(network.name)_\(id)_Show_Hide"
    case .adShowClick(let network, let id, _):
      return "\(network.name)_\(id)_Show_Click"
    case .adEarnReward(let network, let id, _):
      return "\(network.name)_\(id)_Earn_Reward"
    case .adPayRevenue(let network, let id, _):
      return "\(network.name)_\(id)_Pay_Revenue"
    case .adNoRevenue(let network, let id, _):
      return "\(network.name)_\(id)_No_Revenue"
    }
  }
  
  var parameters: [String: Any]? {
    switch self {
    case .adLoadSuccess(_, _, let time):
      return ["time": time]
    case .adLoadFail(_, _, let error):
      return ["error_code": (error as? NSError)?.code ?? "?"]
    case .adShowCheck(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowRequest(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowReady(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowNoReady(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowSuccess(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowHide(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowClick(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adEarnReward(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adPayRevenue(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adNoRevenue(_, _, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowFail(_, _, let error, let viewController):
      guard let topVC = UIApplication.topViewController() else {
        return nil
      }
      return [
        "screen": (viewController ?? AdManager.shared.rootViewController ?? topVC).getScreen(),
        "error_code": (error as? NSError)?.code ?? "?"
      ]
    default:
      return nil
    }
  }
}
