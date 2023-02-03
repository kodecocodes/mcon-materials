//
//  BonjourResultHandler.swift
//  Sky (iOS)
//
//  Created by Marin Todorov on 11/21/22.
//

import Foundation
import Distributed

actor BonjourResultHandler: DistributedTargetInvocationResultHandler {
  private(set) var result: Result<Data?, any Error>?

  func onThrow<Err>(error: Err) async throws where Err: Error {
    result = .failure(error)
  }
  typealias SerializationRequirement = BonjourActorSystem.SerializationRequirement

  func onReturn<Res>(value: Res) async throws where Res: SerializationRequirement {
    result = Result { try JSONEncoder().encode(value) }
  }

  func onReturnVoid() async throws {
    result = .success(nil)
  }
}
