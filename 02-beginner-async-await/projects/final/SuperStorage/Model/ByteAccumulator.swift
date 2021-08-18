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
///
import Foundation

/// Type that accumulates incoming data into an array of bytes.
class ByteAccumulator: CustomStringConvertible {
  private var offset = 0
  private var counter = 0
  
  private let name: String
  private let size: Int
  private let chunkCount: Int
  private(set) var bytes: [UInt8]

  /// Creates a named byte accumulator.
  init(name: String, size: Int) {
    self.name = name
    self.size = size
    chunkCount = max(Int(Double(size) / 20), 1)
    bytes = [UInt8](repeating: 0, count: size)
  }
  
  /// Appends a byte to the accumulator.
  func append(_ byte: UInt8) {
    bytes[offset] = byte
    counter += 1
    offset += 1
  }
  
  /// Executes the given closure as an operation accumulating bytes.
  func batch(_ block: () async throws -> Void) async throws -> Bool {
    counter = 0
    try await block()
    return counter > 0
  }
  
  /// `true` if the current batch is filled with bytes.
  var isBatchCompleted: Bool {
    return counter >= chunkCount
  }
  
  /// The overall progress.
  var progress: Double {
    Double(offset) / Double(size)
  }
  
  var description: String {
    "[\(name)] \(sizeFormatter.string(fromByteCount: Int64(offset)))"
  }
}
