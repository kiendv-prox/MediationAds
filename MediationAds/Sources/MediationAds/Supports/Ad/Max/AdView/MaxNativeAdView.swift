//
//  MaxNativeAdView.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 07/08/2024.
//

import UIKit
import SnapKit
import AppLovinSDK

open class MaxNativeAdView: UIView, AdViewProtocol {
  private var nativeAdView: MANativeAdView?
  private var nativeAd: MaxNativeAd?
  private weak var rootViewController: UIViewController?
  private var placement: String?
  private var didReceive: Handler?
  private var didError: Handler?
  
  open override func awakeFromNib() {
    super.awakeFromNib()
    addComponents()
    setConstraints()
    setProperties()
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    addComponents()
    setConstraints()
    setProperties()
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  public override func removeFromSuperview() {
    self.nativeAd = nil
    super.removeFromSuperview()
  }
  
  open override func draw(_ rect: CGRect) {
    super.draw(rect)
    setColor()
  }
  
  open func addComponents() {}
  
  open func setConstraints() {}
  
  open func setProperties() {}
  
  open func setColor() {}
  
  public func load(placement: String,
                   nativeAdView: MANativeAdView,
                   rootViewController: UIViewController,
                   didReceive: Handler?,
                   didError: Handler?
  ) {
    self.rootViewController = rootViewController
    self.placement = placement
    self.nativeAdView = nativeAdView
    self.didReceive = didReceive
    self.didError = didError
    
    switch AdManager.shared.status(type: .onceUsed(.native), placement: placement) {
    case false:
      print("[MediationAd] [AdManager] [AdMob] [NativeAd] Ads are not allowed to show! (\(placement))")
      errored()
      return
    case true:
      break
    default:
      errored()
      return
    }
    
    guard let native = AdManager.shared.getAd(type: .onceUsed(.native), placement: placement) as? Native else {
      return
    }
    LogEventManager.shared.log(event: .adShowCheck(.max, placement, rootViewController))
    
    if nativeAd == nil {
      guard native.status else {
        return
      }
      
      if let nativeAd = AdManager.shared.getNativePreload(placement: placement) {
        self.nativeAd = nativeAd as? MaxNativeAd
      } else {
        self.nativeAd = MaxNativeAd()
        nativeAd?.config(ad: native, rootViewController: rootViewController, into: nativeAdView)
      }
    }
    
    guard let nativeAd else {
      return
    }
    LogEventManager.shared.log(event: .adShowRequest(.max, placement, rootViewController))
    switch nativeAd.getState() {
    case .receive:
      config(nativeAd: nativeAd.getAd(), nativeAdView: nativeAd.getAdView())
    case .error:
      errored()
    case .loading:
      nativeAd.bind { [weak self] in
        guard let self else {
          return
        }
        config(nativeAd: nativeAd.getAd(), nativeAdView: nativeAd.getAdView())
      } didError: { [weak self] in
        guard let self else {
          return
        }
        self.errored()
      }
    default:
      return
    }
  }
  
  public func destroyAd() -> Bool {
    let state = nativeAd?.getState()
    guard state == .receive || state == .error else {
      return false
    }
    self.nativeAd = nil
    return true
  }
}

extension MaxNativeAdView {
  private func errored() {
    didError?()
  }
  
  @MainActor
  private func config(nativeAd: MANativeAd?, nativeAdView: MANativeAdView?) {
    guard let nativeAd, let nativeAdView else {
      return
    }
    self.nativeAdView?.removeFromSuperview()
    self.addSubview(nativeAdView)
    nativeAdView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    
    if let mediaContentView = nativeAdView.mediaContentView, nativeAd.mediaContentAspectRatio > 0 {
      let heightConstraint = NSLayoutConstraint(
        item: mediaContentView,
        attribute: .height,
        relatedBy: .equal,
        toItem: mediaContentView,
        attribute: .width,
        multiplier: CGFloat(1.0 / nativeAd.mediaContentAspectRatio),
        constant: 0)
      heightConstraint.isActive = true
    }
    
    if let placement {
      LogEventManager.shared.log(event: .adShowSuccess(.max, placement, rootViewController))
    }
    
    self.nativeAdView = nativeAdView
    didReceive?()
  }
}
