//
//  StringExtension.swift
//  MediationAd
//
//  Created by Trịnh Xuân Minh on 22/08/2024.
//

import Foundation

extension String {
  func lastCharacters(_ count: Int) -> String {
    guard count > 0 else {
      return String()
    }
    guard string.count > count else {
      return self
    }
    
    let endIndex = self.index(self.endIndex, offsetBy: -count)
    return String(self[endIndex...])
  }
  
  func cleanAndFormatString() -> String {
    // 1. Loại bỏ khoảng trắng và ký tự xuống dòng ở đầu và cuối chuỗi
    var result = self.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // 2. Thay thế các ký tự lạ bằng ký tự rỗng
    let pattern = "[^a-zA-Z0-9\\s]"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: result.utf16.count)
    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
    
    // 3. Chuyển tất cả khoảng trắng thành dấu gạch dưới "_"
    result = result.replacingOccurrences(of: " ", with: "_")
    
    return result
  }
}
