//
//  BonjourActorSystem.swift
//  Sky (iOS)
//
//  Created by Marin Todorov on 11/20/22.
//

import Foundation
import Distributed
import MultipeerConnectivity
import os

final class BonjourActorSystem: DistributedActorSystem, ObservableObject, @unchecked Sendable {
  // MARK: - Setup

  typealias ActorID = String
  typealias SerializationRequirement = Codable

  typealias InvocationEncoder = BonjourInvocationEncoder
  typealias InvocationDecoder = BonjourInvocationDecoder
  typealias ResultHandler = BonjourResultHandler

  private let lock = OSAllocatedUnfairLock()
  private var actors: [String: any DistributedActor] = [:] {
    didSet {
      let newCount = actors.count
      let names = actors.keys.filter { $0 != localName }
      Task { @MainActor in
        actorCount = newCount
        connectedActors = names
      }
    }
  }
  private let decoder = JSONDecoder()

  let localName: String
  @Published var actorCount = 0
  @Published var connectedActors: [String] = []

  // MARK: - Initialization

  var service: BonjourService!

  init(localName: String) {
    self.localName = localName
    self.service = BonjourService(localName: UIDevice.current.name, actorSystem: self)
  }

  func resolve<Act>(id: String, as actorType: Act.Type) throws -> Act? where Act: DistributedActor, String == Act.ID {
    return withActors { $0[id] as? Act }
  }

  func assignID<Act>(_ actorType: Act.Type) -> String where Act: DistributedActor, String == Act.ID {
    service.localSystemName.displayName
  }

  func resignID(_ id: String) {
    withActors { $0.removeValue(forKey: id) }
  }

  func actorReady<Act>(_ actor: Act) where Act: DistributedActor, ActorID == Act.ID {
    withActors { $0[actor.id] = actor }
  }

  @discardableResult
  func withActors<Result>(_ block: (inout [String: any DistributedActor]) -> Result) -> Result {
    return lock.withLock { block(&actors) }
  }

  // MARK: Remote calls
  func makeInvocationEncoder() -> BonjourInvocationEncoder {
    BonjourInvocationEncoder()
  }

  func remoteCall<Act, Err, Res>(
    on recipientActor: Act,
    target: RemoteCallTarget,
    invocation: inout InvocationEncoder,
    throwing: Err.Type,
    returning: Res.Type
  ) async throws -> Res where Act: DistributedActor,
    Act.ID == ActorID,
    Err: Error,
    Res: SerializationRequirement {
      var invocation = invocation
      invocation.setCallSignature(target.identifier)

      let response = try await service.send(invocation: invocation, to: recipientActor.id)
      guard let result = response.result else {
        throw "Result not found in response"
      }
      return try JSONDecoder().decode(Res.self, from: result)
  }

  func remoteCallVoid<Act, Err>(
    on recipientActor: Act,
    target: RemoteCallTarget,
    invocation: inout InvocationEncoder,
    throwing: Err.Type
  ) async throws where Act: DistributedActor,
    Act.ID == ActorID,
    Err: Error {
      var invocation = invocation
      invocation.setCallSignature(target.identifier)

      _ = try await service.send(invocation: invocation, to: recipientActor.id)
  }
}

extension BonjourActorSystem {
  func didReceiveInvocation(_ invocationMessage: InvocationMessage, data: Data, from sender: MCPeerID) {
    guard let recipient = withActors({ $0[localName] }) else {
      return
    }

    Task {
      let target = RemoteCallTarget(invocationMessage.callSignature)
      var invocationDecoder = BonjourInvocationDecoder(data: data)
      let resultHandler = ResultHandler()

      do {
        try await executeDistributedTarget(
          on: recipient,
          target: target,
          invocationDecoder: &invocationDecoder,
          handler: resultHandler
        )

        let responseData = try await resultHandler.result?.get()
        let response = TaskResponse(result: responseData, id: invocationMessage.id)
        try self.service.send(response: response, to: sender)
      } catch {
        // Let the invocation timeout and the sender will retry
        print(error)
      }
    }
  }

  func connectivityChangedFor(deviceName name: String, to connected: Bool) {
    print("Connectivity: \(name) \(connected)")
  }
}
