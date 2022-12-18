//
//  BonjourActorSystem.swift
//  Sky (iOS)
//
//  Created by Marin Todorov on 11/20/22.
//

import Foundation
import Distributed
import MultipeerConnectivity

final class BonjourActorSystem: DistributedActorSystem, @unchecked Sendable {
  // MARK: - Setup

  typealias ActorID = String
  typealias SerializationRequirement = Codable

  typealias InvocationEncoder = BonjourInvocationEncoder
  typealias InvocationDecoder = BonjourInvocationDecoder
  typealias ResultHandler = BonjourResultHandler

  let peers = PeerList()

  private let decoder = JSONDecoder()
  private(set) var localName: String

  // MARK: - Initialization

  var transport: BonjourService!
  var localSystem: ScanActor!

  init(localName: String) {
    self.localName = localName
    self.transport = BonjourService(localName: UIDevice.current.name, actorSystem: self)
    self.localSystem = ScanActor(name: localName, actorSystem: self)
    self.peers.add(localSystem)
  }

  func resolve<Act>(id: String, as actorType: Act.Type) throws -> Act? where Act: DistributedActor, String == Act.ID {
    return peers.get(id) as? Act
  }

  func assignID<Act>(_ actorType: Act.Type) -> String where Act: DistributedActor, String == Act.ID {
    transport.localSystemName.displayName
  }

  func resignID(_ id: String) {
    peers.remove(id)
  }

  func actorReady<Act>(_ actor: Act) where Act: DistributedActor, ActorID == Act.ID {
    peers.add(actor)
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

      let response = try await transport.send(invocation: invocation, to: recipientActor.id)
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

      _ = try await transport.send(invocation: invocation, to: recipientActor.id)
  }
}

extension BonjourActorSystem {
  func didReceiveInvocation(_ invocationMessage: InvocationMessage, data: Data, from sender: MCPeerID) {
    guard let recipient = peers.get(localName) else {
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
        try self.transport.send(response: response, to: sender)
      } catch {
        // Let the invocation timeout and the sender will retry
        print(error)
      }
    }
  }
}

extension BonjourActorSystem {
  func firstAvailableSystem() async throws -> ScanActor {
    while true {
      for nextID in peers.ids {
        guard let nextSystem = try? ScanActor.resolve(id: nextID, using: self),
          let remoteTaskCount = try? await nextSystem.count,
          remoteTaskCount < 4 else {
          continue
        }

        do {
          try await nextSystem.commit()
          return nextSystem
        } catch { }
      }
      try await Task.sleep(for: .seconds(0.1))
    }
    fatalError("Will never execute")
  }
}
