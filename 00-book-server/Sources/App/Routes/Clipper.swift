//
//  File.swift
//  File
//
//  Created by Marin on 25.07.21.
//

import Foundation
import Vapor

fileprivate var messages = [String]()
fileprivate let queue = DispatchQueue(label: "sync")

struct Clipper {
  static var formatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter
  }
  
  static func routes(_ app: Application) throws {
    
    app.get("cli", "chat") { req -> Response in
      var currentIndex = queue.sync { max(messages.count - 3, 0) }
      
      let response = Response(body: .init(stream: { writer in
        guard let user = try? req.query.decode(String.self) else { return }
        messages.append("[\(user) connected]\r\n")

        req.eventLoop.scheduleRepeatedTask(initialDelay: .zero, delay: .seconds(1)) { task in
          let buffer = queue.sync { messages }
          
          if buffer.count > currentIndex {
            let pending = buffer[currentIndex..<buffer.count].joined(separator: "\r\n").appending("\r\n")
            writer.write(.buffer(.init(string: pending)), promise: nil)
            currentIndex = buffer.count
          }
        }
      }))

      response.headers.add(name: .contentType, value: "application/octet-stream")
      return response
    }
    
    app.post("cli", "say") { req -> String in
      if let message = req.body.string {
        queue.sync {
          messages.append("\(formatter.string(from: Date())) \(message)")
        }
      }
      return "OK"
    }

  }
}
