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
import CoreLocation
import Combine
import UIKit

/// The app model that communicates with the server.
class BlabberModel: ObservableObject {
  var username = ""
  var urlSession = URLSession.shared
  
  init() {
    
  }
  
  /// Current live updates
  @Published var messages = [Message]()
  
  /// Shares the current user's address in chat.
  func shareLocation() async throws {
    let manager = CLLocationManager()
    manager.requestWhenInUseAuthorization()
    guard [CLAuthorizationStatus.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) else {
      throw "The app isn't authorized to use location data"
    }
    
    var delegate: ChatLocationDelegate? = nil
    let location: CLLocation = try await withCheckedThrowingContinuation { continuation in
      delegate = ChatLocationDelegate(continuation: continuation)
      manager.delegate = delegate
      manager.startUpdatingLocation()
    }
    print(location.description)
    
    let address: String = try await withCheckedThrowingContinuation({ continuation in
      AddressEncoder.addressFor(location: location) { address, error in
        switch (address, error) {
        case (nil, .some(let error)):
          continuation.resume(throwing: error)
        case (.some(let address), nil):
          continuation.resume(returning: address)
        case (nil, nil):
          continuation.resume(throwing: "Address encoding failed")
        case (.some(let address), .some(let error)):
          continuation.resume(returning: address)
          print(error)
        }
      }
    })
    
    try await say("📍 \(address)")
  }
  
  /// Does a countdown and sends the message.
  func countdown(to message: String) async throws {
    guard !message.isEmpty else { return }
    
    //    let counter = AsyncStream(String.self) { continuation in
    //      var count = 3
    //      Timer.scheduledTimer(withTimeInterval: 1.0,
    //        repeats: true) { timer in
    //        guard count > 0 else {
    //          timer.invalidate()
    //          continuation.yield(with: .success("🎉 " + message))
    //          return
    //        }
    //
    //        continuation.yield("\(count) ...")
    //        count -= 1
    //      }
    //    }
    
    var count = 3
    let counter = AsyncStream<String> {
      do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
      } catch {
        return nil
      }
      
      defer { count -= 1 }
      
      switch count {
      case 3, 2, 1 : return "\(count)..."
      case 0: return "🎉 " + message
      default: return nil
      }
    }
    
    //    for await countdownMessage in counter {
    //      try await say(countdownMessage)
    //    }
    try await counter.forEach { [weak self] in
      try await self?.say($0)
    }
  }
  
  /// Start live chat updates
  @MainActor
  func chat() async throws {
    guard let query = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      throw "Invalid username"
    }
    let url = URL(string: "http://localhost:8080/chat/room?\(query)")!
    
    let (stream, response) = try await liveURLSession.bytes(from: url, delegate: nil)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    print("Start live updates")
    
    try await withTaskCancellationHandler {
      print("End live updates")
      messages = []
    } operation: {
      try await readMessages(stream: stream)
    }
  }
  
  /// Reads the server chat stream and updates the data model.
  @MainActor
  private func readMessages(stream: URLSession.AsyncBytes) async throws {
    var iterator = stream.lines.makeAsyncIterator()
    
    guard let first = try await iterator.next() else {
      throw "No response from server"
    }
    
    guard let data = first.data(using: .utf8),
          let status = try? JSONDecoder().decode(ServerStatus.self, from: data) else {
            throw "Invalid response from server"
          }
    
    messages.append(
      Message(
        id: UUID(),
        user: nil,
        message: "\(status.activeUsers) active users",
        date: Date()
      )
    )
    
    let notifications = Task {
      await observeAppStatus()
    }
    defer {
      notifications.cancel()
    }
    
    for try await line in stream.lines {
      if let data = line.data(using: .utf8),
         let update = try? JSONDecoder()
          .decode(Message.self, from: data) {
        
        messages.append(update)
      }
    }
  }
  
  func observeAppStatus() async {
    Task {
      for await _ in await NotificationCenter.default.notifications(for: UIApplication.willResignActiveNotification) {
        try? await say("\(username) went away", isSystemMessage: true)
      }
    }
    
    Task {
      for await _ in await NotificationCenter.default.notifications(for: UIApplication.didBecomeActiveNotification) {
        try? await say("\(username) came back", isSystemMessage: true)
      }
    }
  }
  
  /// Sends the user's message to the chat server
  func say(_ text: String, isSystemMessage: Bool = false) async throws {
    guard !text.isEmpty else { return }
    let url = URL(string: "http://localhost:8080/chat/say")!
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(
      Message(id: UUID(), user: isSystemMessage ? nil : username, message: text, date: Date())
    )
    
    let (_, response) = try await urlSession.data(for: request, delegate: nil)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
  }
  
  /// A URL session that goes on indefinitely, receiving live updates.
  private var liveURLSession: URLSession = {
    var configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = .infinity
    return URLSession(configuration: configuration)
  }()
}

extension AsyncSequence {
  func forEach(_
               block: (Element) async throws -> Void) async throws {
    
    for try await element in self {
      try await block(element)
    }
  }
}
