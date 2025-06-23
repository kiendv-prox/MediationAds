//
//  TimeManager.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 20/08/2024.
//

import Foundation
import AVFoundation

class TimeManager {
  static let shared = TimeManager()
  
  private var startTimes: [String: CFTimeInterval] = [:]
  
  func start(event: Event) {
    let start = CACurrentMediaTime()
    startTimes[event.key] = start
  }
  
  func end(event: Event) -> Double {
    let end = CACurrentMediaTime()
    guard let start = startTimes.removeValue(forKey: event.key) else {
      return 0
    }
    return Double(end - start).rounded(decimalPlaces: 1)
  }
  
  enum Event {
    case appManagerConfig
    case remoteManagerLoad
    case releaseManagerCheck
    case consentManagerCheck
    case adLoad(String)
    
    var key: String {
      switch self {
      case .adLoad(let id):
        return "\(self)_\(id)"
      default:
        return "\(self)"
      }
    }
  }
}
