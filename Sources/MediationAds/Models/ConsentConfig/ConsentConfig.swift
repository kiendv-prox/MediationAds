//
//  ConsentConfig.swift
//  
//
//  Created by Trịnh Xuân Minh on 30/07/2024.
//

import Foundation

struct ConsentConfig: Codable {
  let status: Bool
  let dialog: Bool
  
  enum CodingKeys: String, CodingKey {
    case status
    case dialog = "status_dialog"
  }
}
