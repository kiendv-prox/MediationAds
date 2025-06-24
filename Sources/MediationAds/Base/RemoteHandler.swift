//
//  RemoteHandler.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 02/08/2024.
//

import Foundation
import FirebaseRemoteConfig

public typealias RemoteHandler = ((RemoteManager.State, RemoteConfig) -> Void)
