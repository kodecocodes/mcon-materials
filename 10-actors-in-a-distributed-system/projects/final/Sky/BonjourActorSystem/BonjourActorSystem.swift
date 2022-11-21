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
    print("REG ADDED LOCAL '\(localName)'")
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

      print("Remote call:")
      print("  - actor: '\(recipientActor.id)'")
      print("  - target: '\(target.description)'")
      print("  - return: '\(returning)'")

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
      print("Remote call:")
      print("  - actor: '\(recipientActor.id)'")
      print("  - target: '\(target.description)'")
      print("  - return: 'Void'")

      var invocation = invocation
      invocation.setCallSignature(target.identifier)

      let _ = try await transport.send(invocation: invocation, to: recipientActor.id)
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
          print("Received invocation: ")
          print(" - recipient '\(recipient.id)'")
          print(" - call: \(target.description)")

          try await executeDistributedTarget(on: recipient, target: target, invocationDecoder: &invocationDecoder, handler: resultHandler)

          let responseData = try await resultHandler.result?.get()
          let response = TaskResponse(result: responseData, id: invocationMessage.id)
          try self.transport.send(response: response, to: sender)

          print("SENT response '\(response.result)'")
          print()
        } catch {
          // Let the invocation timeout and the sender will retry
          print("ERROR: '\(error.localizedDescription)'")
          print(error)
          print()
        }
      }
  }
}

extension BonjourActorSystem {
  func firstAvailableSystem() async -> ScanActor {
    while true {
      for nextID in peers.ids {
        print("REG nextID '\(nextID)'")

        guard let nextSystem = try? ScanActor.resolve(id: nextID, using: self) else {
          print("REG can't get actor for id '\(nextID)'")
          continue
        }
        guard let remoteTaskCount = try? await nextSystem.count else {
          print("REG id '\(nextID)' could not get remote count")
          continue
        }
        guard remoteTaskCount < 4 else {
          print("REG id \(nextID) has already \(remoteTaskCount) tasks")
          continue
        }

        do {
          try await nextSystem.commit()
          return nextSystem
        } catch { }
      }
      await Task.sleep(seconds: 0.1)
    }
    fatalError("Will never execute")
  }
}
