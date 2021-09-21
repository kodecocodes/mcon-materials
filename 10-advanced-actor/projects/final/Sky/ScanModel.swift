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

class ScanModel: ObservableObject {
  // MARK: - Private state
  private var counted = 0
  private var lastSec = 0

  // MARK: - Public, bindable state

  /// Currently scheduled for execution tasks.
  @MainActor @Published var scheduled = 0 {
    didSet {
      Task {
        let systemCount = await systems.systems.count
        isCollaborating = scheduled > 0 && systemCount > 1
      }
    }
  }

  /// Completed scan tasks per second.
  @MainActor @Published var countPerSecond = 0

  /// Completed scan tasks.
  @MainActor @Published var completed = 0

  @Published var total: Int

  @MainActor @Published var isConnected = false
  private var systems: Systems
  private(set) var service: ScanTransport

  @MainActor @Published var isCollaborating = false

  // MARK: - Methods

  init(total: Int, localName: String) {
    self.total = total
    let localSystem = ScanSystem(name: localName)
    systems = Systems(localSystem)
    service = ScanTransport(localSystem: localSystem)
    service.taskModel = self
    systemConnectivityHandler()
  }

  func run(_ task: ScanTask) async throws -> String {
    Task { @MainActor in scheduled += 1 }
    defer {
      Task { @MainActor in scheduled -= 1 }
    }
    return try await systems.localSystem.run(task)
  }

  func systemConnectivityHandler() {
    Task {
      for await notification in
        NotificationCenter.default.notifications(named: .connected) {
        if let name = notification.object as? String {
          print("[Notification] Connected: \(name)")
          await systems.addSystem(name: name, service: self.service)
          Task { @MainActor in
            isConnected = await systems.systems.count > 1
          }
        }
      }
    }
    Task {
      for await notification in
        NotificationCenter.default.notifications(named: .disconnected) {
        if let name = notification.object as? String {
          print("[Notification] Disconnected: \(name)")
          await systems.removeSystem(name: name)
          Task { @MainActor in
            isConnected = await systems.systems.count > 1
          }
        }
      }
    }
  }

  enum ScanTaskResult {
    case success(String)
    case failed(ScanTask)
  }

  func runAllTasks() async throws {
    try await withThrowingTaskGroup(
      of: ScanTaskResult.self
    ) { [weak self] group in
      guard let self = self else {
        throw "The model failed"
      }

      for number in 0 ..< total {
        let system = await systems.firstAvailableSystem()
        group.addTask {
          return await self.worker(number: number, system: system)
        }
      }

      for try await result in group {
        switch result {
        case .success(let result):
          print("Completed: \(result)")
        case .failed(let task):
          group.addTask(priority: .high) {
            print("Re-run task: \(task.input)")
            return await self.worker(number: task.input, system: self.systems.localSystem)
          }
        }
      }
      await MainActor.run {
        countPerSecond = 0
        scheduled = 0
      }
      print("Done.")
    }
  }

  func worker(number: Int, system: ScanSystem) async
  -> ScanTaskResult {
    Task { @MainActor in onScheduled() }

    let task = ScanTask(input: number)
    let result: String
    do {
      result = try await system.run(task)
    } catch {
      return .failed(task)
    }

    Task { @MainActor in onTaskCompleted() }
    return .success(result)
  }
}

// MARK: - Tracking task progress.
extension ScanModel {
  @MainActor
  private func onTaskCompleted() {
    completed += 1
    counted += 1
    scheduled -= 1

    let now = Int(Date.now.timeIntervalSinceReferenceDate.rounded())
    if lastSec != now {
      self.countPerSecond = self.counted / (now - lastSec)
      self.counted = 0
      lastSec = now
    }
  }

  @MainActor
  private func onScheduled() {
    scheduled += 1
  }
}
