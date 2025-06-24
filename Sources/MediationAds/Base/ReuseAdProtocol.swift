//
//  AdProtocol.swift
//  
//
//  Created by Trịnh Xuân Minh on 23/06/2022.
//

import UIKit

@objc protocol ReuseAdProtocol {
  func config(didFail: Handler?, didSuccess: Handler?)
  func config(id: String, name: String)
  func isPresent() -> Bool
  func isExist() -> Bool
  func show(placement: String,
            rootViewController: UIViewController,
            didFail: Handler?,
            willPresent: Handler?,
            didEarnReward: Handler?,
            didHide: Handler?)
}

extension ReuseAdProtocol {
  func config(timeout: Double) {}
}
