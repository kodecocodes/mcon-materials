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
import Vapor

struct ServerStatus: Codable {
  let activeUsers: Int
}

struct Message: Codable {
  let id: UUID
  let user: String?
  let message: String
  var date: Date
}

var responseUUID = UUID()

fileprivate var messages: [Message] = []

fileprivate let queue = DispatchQueue(label: "sync")
fileprivate var users = [String: Date]()

func countActiveUsers() -> Int {
  // Return the nr of users who wrote in the last 5 minutes.
  return users.values.filter { $0 > Date().addingTimeInterval(-300) }.count
}

struct Blabber {
  static var formatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter
  }
  
  static let encoder = JSONEncoder()
  
  static func routes(_ app: Application) throws {
    app.get("chat", "room") { req -> Response in
      var currentIndex = queue.sync { max(messages.count - 3, 0) }
      var hasPrintedConnectionMessage = false
      
      let response = Response(body: .init(stream: { writer in
        guard let user = try? req.query.decode(String.self) else { return }
        queue.sync {
          users[user] = Date()
        }
        
        // Return server status
        let status = ServerStatus(activeUsers: countActiveUsers())
        let data = try! encoder.encode(status) + "\r\n".data(using: .utf8)!
        writer.write(.buffer(.init(data: data)), promise: nil)
        
        // Loop over messages and return to client
        req.eventLoop.scheduleRepeatedTask(initialDelay: .zero, delay: .seconds(1)) { task in
          let buffer = queue.sync { messages }
          if buffer.count > currentIndex {
            for message in buffer[currentIndex..<buffer.count] {
              let data = try! encoder.encode(message) + "\r\n".data(using: .utf8)!
              writer.write(.buffer(.init(data: data)), promise: nil)
            }
            currentIndex = buffer.count
          }
          
          if !hasPrintedConnectionMessage {
            queue.sync {
              let message = Message(id: UUID(), user: nil, message: "\(user) connected", date: Date())
              messages.append(message)
            }
            hasPrintedConnectionMessage = true
          }
        }

      }))

      response.headers.add(name: .contentType, value: "application/octet-stream")
      return response
    }
    
    app.post("chat", "say") { req -> String in
      if let bodyData = req.body.data, var newMessage = try? bodyData.getJSONDecodable(Message.self, at: 0, length: bodyData.readableBytes) {
        newMessage.date = Date()
        queue.sync {
          if let user = newMessage.user {
            users[user] = Date()
            bot(last: newMessage)
          }
          messages.append(newMessage)
        }
      }
      return "OK"
    }

  }
  
  static let botMessages: [String] = [
    "I'm also here, in case you need to talk",
    "🍦🦕🥳",
    "Something, something, this way comes 🤫",
    "Today's lottery numbers are: 4, 8, 15, 16, 23, 42",
    "Hey hey hey",
    "I wish it was taco Tuesday today 🥺",
    "Sorry for jumping in but how do I turn on my camera in this chat?",
    "parrot"
  ]
  
  static func bot(last: Message) {
    let newUUID = UUID()
    responseUUID = newUUID
    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
      if responseUUID == newUUID {
        queue.sync {
          let text = botMessages.randomElement()!
          if text == "parrot" {
            messages.append(Message(id: UUID(), user: "Bottley", message: last.message, date: Date()))
          } else {
            messages.append(Message(id: UUID(), user: "Bottley", message: text, date: Date()))
          }
        }
      }
    }
  }
}
