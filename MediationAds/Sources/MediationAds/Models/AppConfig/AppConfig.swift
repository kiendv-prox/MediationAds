//
//  AppConfig.swift
//  MediationAd
//
//  Created by Dev_iOS on 20/6/25.
//

import Foundation

public struct AppConfig {
    let appID: String
    let issuerID: String
    let keyID: String
    let privateKey: String
    let adConfigKey: String
    let defaultData: Data
    let maxSdkKey: String?
    let devKey: String?
    let trackingTimeout: Double?
    
    public init(appID: String, issuerID: String, keyID: String, privateKey: String, adConfigKey: String, defaultData: Data, maxSdkKey: String?, devKey: String?, trackingTimeout: Double?) {
        self.appID = appID
        self.issuerID = issuerID
        self.keyID = keyID
        self.privateKey = privateKey
        self.adConfigKey = adConfigKey
        self.defaultData = defaultData
        self.maxSdkKey = maxSdkKey
        self.devKey = devKey
        self.trackingTimeout = trackingTimeout
    }
}
