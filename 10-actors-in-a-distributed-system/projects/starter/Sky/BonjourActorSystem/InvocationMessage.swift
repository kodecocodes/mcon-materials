//
//  InvocationMessage.swift
//  Sky (iOS)
//
//  Created by Marin Todorov on 11/21/22.
//

import Foundation

struct InvocationMessage: Codable {
  var id = UUID()
  var callSignature = ""
  var arguments: [Data] = []
  var errorType = ""
  var returnType = ""

  static func typeWithName(_ name: String) -> Any.Type? {
    switch name {
    case "Swift.Int": return Int.self
    case "Foundation.Data": return Data.self
    default: return nil
    }
  }
}
