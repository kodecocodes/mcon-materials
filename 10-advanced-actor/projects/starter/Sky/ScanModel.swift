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
  @MainActor @Published var scheduled = 0

  /// Completed scan tasks per second.
  @MainActor @Published var countPerSecond = 0

  /// Completed scan tasks.
  @MainActor @Published var completed = 0

  @Published var total: Int

  // MARK: - Methods

  init(total: Int, localName: String) {
    self.total = total
  }

  func runAllTasks() async throws {
    try await withThrowingTaskGroup(of: Result<String, Error>.self) { [weak self] group in
      guard let self = self else {
        throw "The model failed"
      }
      let batchSize = 4

      for index in 0..<batchSize {
        group.addTask {
          await self.worker(number: index)
        }
      }
      var index = batchSize

      for try await result in group {
        switch result {
        case .success(let result):
          print("Completed: \(result)")
        case .failure(let error):
          print("Failed: \(error.localizedDescription)")
        }

        if index < total {
          group.addTask { [index] in
            await self.worker(number: index)
          }
          index += 1
        }
      }

      await MainActor.run {
        countPerSecond = 0
        scheduled = 0
      }
      print("Done.")
    }
  }

  func worker(number: Int) async -> Result<String, Error> {
    Task { @MainActor in onScheduled() }

    let task = ScanTask(input: number)
    let result: String
    do {
      result = try await task.run()
    } catch {
      return .failure(error)
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
