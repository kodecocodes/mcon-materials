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

/// The download model.
class SuperStorageModel: ObservableObject {
  /// The list of currently running downloads.
  @Published var downloads = [DownloadInfo]()

  func availableFiles() async throws -> [DownloadFile] {
    let url = URL(string: "http://localhost:8080/files/list")!
    let (data, response) = try await URLSession.shared.data(from: url, delegate: nil)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }

    guard let list = try? JSONDecoder()
      .decode([DownloadFile].self, from: data) else {
      throw "The server response was not recognized."
    }

    return list
  }
  
  func status() async throws -> String {
    let url = URL(string: "http://localhost:8080/files/status")!
    let (data, response) = try await
      URLSession.shared.data(from: url, delegate: nil)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    return String(decoding: data, as: UTF8.self)
  }
  
  /// Downloads a file and returns its content.
  func download(file: DownloadFile) async throws -> Data {
    let url = URL(string: "http://localhost:8080/files/download?\(file.name)")!

    await addDownload(name: file.name)
    let (data, response) = try await URLSession.shared.data(from: url, delegate: nil)
    await updateDownload(name: file.name, progress: 1.0)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    return data
  }
  
  /// Downloads a file, returns its data, and updates the download progress in ``downloads``.
  func downloadWithProgress(file: DownloadFile) async throws -> Data {
    return try await downloadWithProgress(fileName: file.name, name: file.name, size: file.size)
  }
  
  /// Downloads a file, returns its data, and updates the download progress in ``downloads``.
  private func downloadWithProgress(fileName: String, name: String, size: Int, offset: Int? = nil) async throws -> Data {
    let url = URL(string: "http://localhost:8080/files/download?\(fileName)")!
    await addDownload(name: name)
    
    let result: (downloadStream: URLSession.AsyncBytes, response: URLResponse)
    
    if let offset = offset {
      let urlRequest = URLRequest(url: url, offset: offset, length: size)
      result = try await
        URLSession.shared.bytes(for: urlRequest, delegate: nil)

      guard (result.response as? HTTPURLResponse)?.statusCode == 206 else {
        throw "The server responded with an error."
      }
    } else {
      result = try await URLSession.shared.bytes(from: url, delegate: nil)

      guard (result.response as? HTTPURLResponse)?.statusCode == 200 else {
        throw "The server responded with an error."
      }
    }
    
    var asyncDownloadIterator = result.downloadStream.makeAsyncIterator()
    
    let accumulator = ByteAccumulator(name: fileName, size: size)
    
    while !stopDownloads, try await accumulator.batch({
      while !accumulator.isBatchCompleted, let byte = try await asyncDownloadIterator.next() {
        accumulator.append(byte)
      }
      
      Task.detached(priority: .medium) { [weak self] in
        await self?.updateDownload(name: fileName, progress: accumulator.progress)
      }
    }) {
      print(accumulator.description)
    }

    if stopDownloads && !Self.supportsPartialDownloads {
      throw CancellationError()
    }

    return Data(accumulator.data)
  }
  
  /// Downloads a file using multiple concurrent connections, returns the final content, and updates the download progress.
  func multiDownloadWithProgress(file: DownloadFile) async throws -> Data {
    var numBatches = 6
    let batchSize = Double(file.size) / Double(numBatches)
    let roundedBatchSize = Int(batchSize.rounded(.down))

    if Double(roundedBatchSize) < batchSize {
      numBatches += 1
    }

    return Data()
  }
  
  /// Flag that stops ongoing downloads.
  var stopDownloads = false

  func reset() {
    stopDownloads = false
    downloads.removeAll()
  }
  
  @TaskLocal static var supportsPartialDownloads = false
}

extension SuperStorageModel {
  /// Adds a new download.
  @MainActor
  func addDownload(name: String) {
    let downloadInfo = DownloadInfo(id: UUID(), name: name, progress: 0.0)
    downloads.append(downloadInfo)
  }
  
  /// Updates a the progress of a given download.
  @MainActor
  func updateDownload(name: String, progress: Double) {
    if let index = downloads.firstIndex(where: { $0.name == name }) {
      var info = downloads[index]
      info.progress = progress
      downloads[index] = info
    }
  }
}