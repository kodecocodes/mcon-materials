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

import UIKit

actor ImageLoader: ObservableObject {
  enum DownloadState {
    case inProgress(Task<UIImage, Error>)
    case completed(UIImage)
    case failed
  }

  private(set) var cache: [String: DownloadState] = [:]

  func add(_ image: UIImage, forKey key: String) {
    cache[key] = .completed(image)
  }

  func image(_ serverPath: String) async throws -> UIImage {
    if let cached = cache[serverPath] {
      switch cached {
      case .completed(let image):
        inMemoryAccessCounter += 1
        inMemoryAcccessContinuation?.yield(inMemoryAccessCounter)
        return image
      case .inProgress(let task):
        return try await task.value
      case .failed: throw "Download failed"
      }
    }

    let download: Task<UIImage, Error> = Task.detached {
      guard let url = URL(string: "http://localhost:8080".appending(serverPath)) else {
        throw "Could not create the download URL"
      }
      print("Download: \(url.absoluteString)")
      let data = try await URLSession.shared.data(from: url).0
      return try resize(data, to: CGSize(width: 200, height: 200))
    }

    cache[serverPath] = .inProgress(download)

    do {
      let result = try await download.value
      add(result, forKey: serverPath)
      return result
    } catch {
      cache[serverPath] = .failed
      throw error
    }
  }

  func clear() {
    cache.removeAll()
  }

  @MainActor private(set) var inMemoryAccess: AsyncStream<Int>?

  private var inMemoryAccessCounter = 0
  private var inMemoryAcccessContinuation: AsyncStream<Int>.Continuation?

  func setUp() async {
    let accessStream = AsyncStream<Int> { continuation in
      inMemoryAcccessContinuation = continuation
    }
    await MainActor.run { inMemoryAccess = accessStream }
  }

  deinit {
    inMemoryAcccessContinuation?.finish()
  }
}
