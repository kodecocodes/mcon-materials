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

@ImageDatabase class DiskStorage {
  private var folder: URL

  init() throws {
    guard let supportFolderURL = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      fatalError("Couldn't open the application support folder")
    }
    let databaseFolderURL = supportFolderURL.appendingPathComponent("database")

    do {
      try FileManager.default.createDirectory(at: databaseFolderURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
      fatalError("Couldn't create the application support folder")
    }

    folder = databaseFolderURL
  }

  nonisolated static func fileName(for path: String) -> String {
    return path.dropFirst()
      .components(separatedBy: .punctuationCharacters)
      .joined(separator: "_")
  }

  func write(_ data: Data, name: String) throws {
    try data.write(to: folder.appendingPathComponent(name), options: .atomic)
  }

  func read(name: String) throws -> Data {
    return try Data(contentsOf: folder.appendingPathComponent(name))
  }

  func remove(name: String) throws {
    try FileManager.default.removeItem(at: folder.appendingPathComponent(name))
  }

  func persistedFiles() throws -> [URL] {
    var result: [URL] = []
    guard let directoryEnumerator = FileManager.default
      .enumerator(at: folder, includingPropertiesForKeys: []) else {
        throw "Could not open the application support folder"
      }
    for case let fileURL as URL in directoryEnumerator {
      result.append(fileURL)
    }
    return result
  }
}
