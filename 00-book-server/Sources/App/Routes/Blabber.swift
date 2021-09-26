//
//  File.swift
//  File
//
//  Created by Marin Todorov on 8/3/21.
//

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
