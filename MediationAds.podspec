Pod::Spec.new do |s|
    s.name             = 'MediationAds'
    s.version          = '1.0.0'
    s.summary          = 'A lightweight Swift package for ad mediation with multiple ad networks.'
    s.description      = <<-DESC
    MediationAds provides a unified interface to manage ad mediation across multiple ad networks,
    including AppLovin MAX (13.3.1), Google AdMob, Meta Audience Network, and Unity Ads.
    It simplifies ad integration using a modular Swift-based structure.
    DESC
    s.homepage         = 'https://github.com/kiendv-prox/MediationAds'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'KienDV' => 'kiendv@proxglobal.com' }
    s.source           = { :git => 'https://github.com/kiendv-prox/MediationAds.git', :tag => s.version.to_s }
    s.static_framework = true
    s.platform         = :ios, '15.6'
    s.swift_versions   = ['5.3', '5.4', '5.5', '5.6', '5.7', '5.8', '5.9', '5.10', '6.0']
    s.source_files     = [
        'Sources/MediationAds/Managers/**/*.swift',
        'Sources/MediationAds/Models/AppConfig/**/*.swift'
    ]

    # Dependency with version pinning
    s.dependency 'AppLovinSDK', '13.3.1'
    s.dependency 'AppLovinMediationGoogleAdapter'
    s.dependency 'AppLovinMediationUnityAdsAdapter'
    s.dependency 'AppLovinMediationByteDanceAdapter'
    s.dependency 'AppLovinMediationFyberAdapter'
    s.dependency 'AppLovinMediationInMobiAdapter'
    s.dependency 'AppLovinMediationIronSourceAdapter'
    s.dependency 'AppLovinMediationVungleAdapter'
    s.dependency 'AppLovinMediationMintegralAdapter'
    s.dependency 'AppLovinMediationFacebookAdapter'
    s.dependency 'AppLovinMediationYandexAdapter'
    s.dependency 'FirebaseRemoteConfig'
    s.dependency 'FirebaseABTesting'
    s.dependency 'FirebaseAnalytics'
    s.dependency 'FirebaseCrashlytics'
    s.dependency 'AppsFlyerFramework', '6.17.0'
    s.dependency 'PurchaseConnector', '6.17.0'

end
