//
//  BonjourInvocationEncoder.swift
//  Sky (iOS)
//
//  Created by Marin Todorov on 11/21/22.
//

import Foundation
import Distributed

struct BonjourInvocationEncoder: DistributedTargetInvocationEncoder {
  typealias SerializationRequirement = BonjourActorSystem.SerializationRequirement

  private let encoder = JSONEncoder()
  private(set) var message = InvocationMessage()

  var data: Data {
    get throws {
      try encoder.encode(message)
    }
  }

  init() {}

  mutating func setCallSignature(_ signature: String) {
    message.callSignature = signature
  }

  mutating func recordGenericSubstitution<T>(_ type: T.Type) throws { }

  mutating func recordErrorType<E>(_ type: E.Type) throws where E: Error {
    message.errorType = String(reflecting: type)
  }

  mutating func recordReturnType<R>(_ type: R.Type) throws where R: SerializationRequirement {
    message.returnType = String(reflecting: type)
  }

  mutating func recordArgument<Value: SerializationRequirement>(
    _ argument: RemoteCallArgument<Value>
  ) throws {
    try message.arguments.append(encoder.encode(argument.value))
  }

  func doneRecording() throws { }
}
