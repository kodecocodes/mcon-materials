//
//  BonjourInvocationDecoder.swift
//  Sky (iOS)
//
//  Created by Marin Todorov on 11/21/22.
//

import Foundation
import Distributed

struct BonjourInvocationDecoder: DistributedTargetInvocationDecoder {
  typealias SerializationRequirement = BonjourActorSystem.SerializationRequirement

  private var message = InvocationMessage()
  private let decoder = JSONDecoder()

  init(data: Data) {
    if let message = try? JSONDecoder().decode(InvocationMessage.self, from: data) {
      self.message = message
    }
  }

  mutating func decodeGenericSubstitutions() throws -> [Any.Type] { [] }

  mutating func decodeNextArgument<Value: SerializationRequirement>() throws -> Value {
    try decoder.decode(Value.self, from: message.arguments.removeFirst())
  }

  mutating func decodeErrorType() throws -> Any.Type? {
    InvocationMessage.typeWithName(message.errorType)
  }

  mutating func decodeReturnType() throws -> Any.Type? {
    InvocationMessage.typeWithName(message.returnType)
  }
}
