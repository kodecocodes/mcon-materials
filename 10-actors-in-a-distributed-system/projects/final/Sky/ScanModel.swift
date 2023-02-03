/// Copyright (c) 2023 Kodeco Inc.
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
        isCollaborating = scheduled > 0
          && actorSystem.actorCount > 1
      }
    }
  }

  /// Completed scan tasks per second.
  @MainActor @Published var countPerSecond: Double = 0

  /// Completed scan tasks.
  @MainActor @Published var completed = 0

  @MainActor @Published var localTasksCompleted: [String] = []

  @Published var total: Int

  let actorSystem: BonjourActorSystem

  init(total: Int, localName: String) {
    self.total = total
    self.actorSystem = BonjourActorSystem(localName: localName)
    systemConnectivityHandler()
  }

  func systemConnectivityHandler() {
    Task {
      for await count in actorSystem.$actorCount.values {
        Task { @MainActor in
          isConnected = count > 1
        }
      }
    }

    Task {
      for await notification in NotificationCenter.default
        .notifications(named: .localTaskUpdate) {
        let status = notification.taskStatus
        let runningTasksCount = try await actorSystem.localActor.count
        Task { @MainActor in
          if scheduled == 0 {
            isCollaborating = runningTasksCount > 0
          }
          localTasksCompleted.append(status)
        }
      }
    }
  }

  func worker(number: Int, actor: ScanActor) async
  -> Result<Data, ScanTaskError> {
    await onScheduled()

    let task = ScanTask(input: number)

    let result: Result<Data, ScanTaskError>
    do {
      result = try .success(await actor.run(task))
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
        let actor = try await
          actorSystem.firstAvailableActor()

        group.addTask {
          return await self.worker(
            number: number,
            actor: actor
          )
        }
      }

      for try await result in group {
        switch result {
        case .success(let result):
          print("Completed: \(result)")
        case .failure(let error):
          group.addTask(priority: .high) {
            print("Re-run task: \(error.task.input).")
            print("Failed with: \(error.underlyingError)")
            return await self.worker(
              number: error.task.input,
              actor: self.actorSystem.localActor
            )
          }
        }
      }

      await MainActor.run {
        completed = 0
        countPerSecond = 0
        scheduled = 0
        counted = 0
      }
      print("Done.")
    }
  }

  struct ScanTaskError: Error {
    let underlyingError: Error
    let task: ScanTask
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
