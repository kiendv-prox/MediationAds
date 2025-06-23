//
//  UIViewControllerExtension.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 26/09/2024.
//

import UIKit

extension UIViewController {
  func getScreen() -> String {
    return String(describing: type(of: self))
  }
}
