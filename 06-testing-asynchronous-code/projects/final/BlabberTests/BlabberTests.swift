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

import XCTest
@testable import Blabber

class BlabberTests: XCTestCase {
  @MainActor
  let model: BlabberModel = {
    // 1
    let model = BlabberModel()
    model.username = "test"

    // 2
    let testConfiguration = URLSessionConfiguration.default
    testConfiguration.protocolClasses = [TestURLProtocol.self]

    // 3
    model.urlSession = URLSession(configuration: testConfiguration)
    model.sleep = { try await Task.sleep(for: .nanoseconds($0)) }
    return model
  }()

  func testModelSay() async throws {
    try await model.say("Hello!")
    let request = try XCTUnwrap(TestURLProtocol.lastRequest)

    XCTAssertEqual(
      request.url?.absoluteString,
      "http://localhost:8080/chat/say"
    )
    let httpBody = try XCTUnwrap(request.httpBody)
    let message = try XCTUnwrap(try? JSONDecoder()
      .decode(Message.self, from: httpBody))

    XCTAssertEqual(message.message, "Hello!")
  }

  func testModelCountdown() async throws {
    async let countdown: Void = model.countdown(to: "Tada!")
    async let messages = TimeoutTask(seconds: 10) {
      await TestURLProtocol.requests
        .prefix(4)
        .compactMap(\.httpBody)
        .compactMap { data in
          try? JSONDecoder()
            .decode(Message.self, from: data).message
        }
        .reduce(into: []) { result, request in
          result.append(request)
        }
    }
    .value
    let (messagesResult, _) = try await (messages, countdown)
    XCTAssertEqual(
      ["3...", "2...", "1...", "🎉 Tada!"],
      messagesResult
    )
  }
}
