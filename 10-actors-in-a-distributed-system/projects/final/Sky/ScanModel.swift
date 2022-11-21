/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation

final class ScanModel: ObservableObject {
  // MARK: - Private state

  private var counted = 0
  private var started = Date()

  // MARK: - Public, bindable state

  @MainActor @Published var isConnected = false
  @MainActor @Published var isCollaborating = false

  @MainActor @Published var scheduled = 0 {
    didSet {
      Task {
        let systemCount = actorSystem.peers.count
        isCollaborating = scheduled > 0 && systemCount > 1
      }
    }
  }

  /// Completed scan tasks per second.
  @MainActor @Published var countPerSecond: Double = 0

  /// Completed scan tasks.
  @MainActor @Published var completed = 0

  @Published var total: Int

  let actorSystem: BonjourActorSystem

  init(total: Int, localName: String) {
    self.total = total
    self.actorSystem = BonjourActorSystem(localName: localName)
    systemConnectivityHandler()
  }

  func systemConnectivityHandler() {
    Task {
      for await notification in
            NotificationCenter.default.notifications(named: .connected) {
        guard let name = notification.object as? String else { continue }
        print("[Notification] Connected: \(name)")

        let remoteActor = try ScanActor.resolve(id: name, using: actorSystem)
        actorSystem.peers.add(remoteActor)

        Task { @MainActor in
          isConnected = actorSystem.peers.count > 1
        }
      }
    }

    Task {
      for await notification in
            NotificationCenter.default.notifications(named: .disconnected) {
        guard let name = notification.object as? String else { return }
        print("[Notification] Disconnected: \(name)")
        actorSystem.peers.remove(name)
        Task { @MainActor in
          isConnected = actorSystem.peers.count > 1
        }
      }
    }

    Task {
      for await _ in
            NotificationCenter.default.notifications(named: .localTaskUpdate) {

        let runningTasksCount = try await actorSystem.localSystem.count
        Task { @MainActor in
          if scheduled == 0 {
            isCollaborating = runningTasksCount > 0
          }
        }
      }
    }

  }

  func worker(number: Int, system: ScanActor) async
  -> Result<Data, ScanTaskError> {
    await onScheduled()

    let task = ScanTask(input: number)

    let result: Result<Data, ScanTaskError>
    do {
      result = try .success(await system.run(task))
    } catch {
      result = .failure(.init(
        underlyingError: error,
        task: task
      ))
    }

    await onTaskCompleted()
    return result
  }

  func runAllTasks() async throws {
    started = Date()
    try await withThrowingTaskGroup(
      of: Result<Data, ScanTaskError>.self
    ) { [unowned self] group in
      for number in 0 ..< total {
        let system = await actorSystem.firstAvailableSystem()

        group.addTask {
          return await self.worker(number: number, system: system)
        }
      }

      for try await result in group {
        switch result {
        case .success(let result):
          print("Completed: \(result)")
        case .failure(let error):
          group.addTask(priority: .high) {
            print(
              "Re-run task: \(error.task.input).",
              "Failed with: \(error.underlyingError.localizedDescription)"
            )
            return await self.worker(
              number: error.task.input,
              system: self.actorSystem.localSystem
            )
          }
        }
      }
      await MainActor.run {
        completed = 0
        countPerSecond = 0
        scheduled = 0
      }
      print("Done.")
    }
  }

}

// MARK: - Tracking task progress.
extension ScanModel {
  @MainActor
  private func onTaskCompleted() {
    completed += 1
    counted += 1
    scheduled -= 1

    countPerSecond = Double(counted) / Date().timeIntervalSince(started)
  }

  @MainActor
  private func onScheduled() {
    scheduled += 1
  }
}

struct ScanTaskError: Error {
  let underlyingError: Error
  let task: ScanTask
}
