//
//  ReleaseManager.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 02/08/2024.
//

import Foundation
import Combine
import SwiftJWT

public class ReleaseManager: @unchecked Sendable {
    public static let shared = ReleaseManager()
    
    public struct ReleaseConfig {
        public let appId: String
        public let keyId: String
        public let issuerId: String
        public let privateKey: String
    }
    
    enum Keys {
        static let cache = "RELEASE_CACHE"
        static let readyForSale = "READY_FOR_SALE"
    }
    
    public enum State: String {
        case unknow
        case waitReview
        case live
        case error
    }
    
    @Published public private(set) var releaseState: State = .unknow
    let releaseSubject = PassthroughSubject<State, Never>()
    private var nowVersion: Double = 0.0
    private var releaseVersion: Double = 0.0
    private let timeout = 15.0
    private var config: ReleaseConfig?
}

extension ReleaseManager {
    func initialize(appID: String,
                    keyID: String,
                    issuerID: String,
                    privateKey: String
    ) {
        config = .init(appId: appID, keyId: keyID, issuerId: issuerID, privateKey: privateKey)
        
        fetch()
        check()
    }
}

extension ReleaseManager {
    private func check() {
        LogEventManager.shared.log(event: .releaseManagerStartCheck)
        guard
            let nowVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let nowVersion = Double(nowVersionString)
        else {
            // Không lấy được version hiện tại.
            change(state: .error)
            return
        }
        self.nowVersion = nowVersion
        
        if nowVersion <= releaseVersion {
            // Version hiện tại đã release, đã được cache.
            change(state: .live)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else {
                    return
                }
                guard releaseState == .unknow else {
                    return
                }
                // Quá thời gian timeout chưa trả về, mặc định trạng thái bật.
                LogEventManager.shared.log(event: .releaseManagerTimeout)
                change(state: .error)
            }
            Task {
                // Check version đang release trên Itunes.
                let itunesReleaseState = await itunesReleaseState()
                switch itunesReleaseState {
                case .live, .error:
                    change(state: itunesReleaseState)
                case .unknow:
                    // Check version đang release trên AppStoreConnect khi dữ liệu itunes chưa kịp cập nhật.
                    let appStoreConnectRelease = await appStoreConnectReleaseState()
                    change(state: appStoreConnectRelease)
                case .waitReview:
                    break
                }
            }
        }
    }
    
    private func itunesReleaseState() async -> State {
        do {
            guard let bundleId = Bundle.main.bundleIdentifier else {
                // Không lấy được bundleId.
                return .error
            }
            
            
            let itunesResponse = try await requestItunesVersion(bundleId: bundleId)
            guard let result = itunesResponse.results.first else {
                // Hiện tại chưa có version nào release.
                return .unknow
            }
            let releaseVersionString = result.version
            guard let releaseVersion = Double(releaseVersionString) else {
                // Không convert được sang dạng số thập phân.
                return .error
            }
            
            if nowVersion <= releaseVersion {
                // Version hiện tại đã release. Cache version.
                update(releaseVersion)
                return .live
            } else {
                // Version hiện tại chưa release.
                return .unknow
            }
        } catch let error {
            // Lỗi không load được version release, mặc định trạng thái bật.
            print("[MediationAd] [ReleaseManager] error: \(error)")
            return .error
        }
    }
    
    private func appStoreConnectReleaseState() async -> State {
        do {
            guard let config, let privateData = config.privateKey.data(using: .utf8) else {
                return .error
            }
            
            let appStoreConnectResponse = try await requestAppStoreConnectVersion(config: config, privateData: privateData)
            guard let version = appStoreConnectResponse.versions.first(where: { $0.attributes.state == Keys.readyForSale }) else {
                // Hiện tại chưa có version nào release.
                return .waitReview
            }
            let releaseVersionString = version.attributes.version
            guard let releaseVersion = Double(releaseVersionString) else {
                // Không convert được sang dạng số thập phân.
                return .error
            }
            
            if nowVersion <= releaseVersion {
                // Version hiện tại đã release. Cache version.
                update(releaseVersion)
                return .live
            } else {
                // Version hiện tại chưa release.
                return .waitReview
            }
        } catch let error {
            // Lỗi không load được version release, mặc định trạng thái bật.
            print("[MediationAd] [ReleaseManager] error: \(error)")
            return .error
        }
    }
    
    private func change(state: State) {
        guard releaseState == .unknow else {
            return
        }
        print("[MediationAd] [ReleaseManager] state: \(state)")
        self.releaseState = state
        releaseSubject.send(state)
        
        let time = TimeManager.shared.end(event: .releaseManagerCheck)
        switch state {
        case .waitReview:
            LogEventManager.shared.log(event: .releaseManagerWaitReview(time))
        case .live:
            LogEventManager.shared.log(event: .releaseManagerLive(time))
        case .error:
            LogEventManager.shared.log(event: .releaseManagerError(time))
        default:
            break
        }
    }
    
    private func fetch() {
        self.releaseVersion = UserDefaults.standard.double(forKey: Keys.cache)
    }
    
    private func update(_ releaseVersion: Double) {
        UserDefaults.standard.set(releaseVersion, forKey: Keys.cache)
        fetch()
    }
}

private extension ReleaseManager {
    
}

private extension ReleaseManager {
    fileprivate func requestAppStoreConnectVersion(config: ReleaseConfig, privateData data: Data) async throws -> AppStoreConnectResponse {
        let jwtSigner = JWTSigner.es256(privateKey: data)
        
        let limitTime = 300.0
        let claims = TokenClaims(iss: config.issuerId,
                                 exp: Date(timeIntervalSinceNow: limitTime),
                                 aud: "appstoreconnect-v1")
        let header = Header(kid: config.keyId)
        var jwt = JWT(header: header, claims: claims)
        
        let token = try jwt.sign(using: jwtSigner)
        
        let endPoint = EndPoint.appStoreConnectVersion(appID: config.appId, token: token)
        return try await APIService.request(from: endPoint, body: data)
    }
    
    fileprivate func requestItunesVersion(bundleId: String) async throws -> ItunesResponse {
        let regionCodeClean: String
        if let regionCode = Locale.current.regionCode,
           let cleanPath = regionCode.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            regionCodeClean = cleanPath
        } else {
            regionCodeClean = "us"
        }
        
        let endPoint = EndPoint.itunesVersion(regionCode: regionCodeClean, bundleId: bundleId)
        
        return try await APIService.request(from: endPoint)
    }
}
