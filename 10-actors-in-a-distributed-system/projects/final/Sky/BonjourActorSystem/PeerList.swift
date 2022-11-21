//
//  ActorRegistry.swift
//  Sky (iOS)
//
//  Created by Marin Todorov on 11/20/22.
//

import Foundation
import Distributed
import os

final class PeerList: @unchecked Sendable {
  private let lock = OSAllocatedUnfairLock()
  private var registry: [String: any DistributedActor] = [:]

  init() { }

  var ids: [String] { Array(registry.keys) }

  var count: Int {
    return lock.withLock {
      return registry.count
    }
  }

  func get(_ id: String) -> (any DistributedActor)? {
    lock.withLock {
      registry[id]
    }
  }

  func add<Act>(_ actor: Act) where Act: DistributedActor, String == Act.ID {
    lock.withLock {
      registry[actor.id] = actor
    }
  }

  func remove(_ id: String) {
    lock.withLock {
      registry[id] = nil
    }
  }
}
