//
//  File.swift
//  File
//
//  Created by Marin Todorov on 8/1/21.
//

import Foundation
import Vapor

fileprivate let symbols = ["AMD", "AAPL", "SNDL", "HOOD", "NOK", "TSLA", "PFE", "NVDA", "BABA"]

struct Ticker: Codable {
  struct Symbol: Codable {
    let name: String
    var value: Double
  }
  
  var symbols: [Symbol]
  
  mutating func enthropy() {
    symbols = symbols.map { symbol in
      Symbol(name: symbol.name, value: max(0, symbol.value + Double.random(in: -3.14...3.14)))
    }
  }
}

struct Stocked {
  static func routes(_ app: Application) throws {

    app.get("littlejohn", "symbols") { req -> Response in
      let responseData = try! JSONEncoder().encode(symbols)
      return Response(body: .init(data: responseData))
    }

    app.get("littlejohn", "ticker") { req -> Response in
      let watched = try? req.query.decode(String.self)
      let names = watched?.components(separatedBy: ",").filter(symbols.contains)

      guard let names = names, !names.isEmpty else {
        let responseData = try! JSONSerialization.data(withJSONObject: ["error": "No valid stock name found."], options: .prettyPrinted)
        return Response(status: .internalServerError, body: .init(data: responseData))
      }
      
      var ticker = Ticker(symbols: names.map { Ticker.Symbol(name: $0, value: Double.random(in: 10...100)) })
      
      let response = Response(body: .init(stream: { writer in
        // Write the initial response
        let initialResponse = try! JSONEncoder().encode(ticker.symbols) + "\n".data(using: .utf8)!
        writer.write(.buffer(.init(data: initialResponse)), promise: nil)

        req.eventLoop.scheduleRepeatedTask(initialDelay: .zero, delay: .seconds(1)) { task in
          ticker.enthropy()
          
          let updateResponse = try! JSONEncoder().encode(ticker.symbols) + "\n".data(using: .utf8)!
          writer.write(.buffer(.init(data: updateResponse)), promise: nil)
        }
      }))

      response.headers.add(name: .contentType, value: "application/octet-stream")
      return response
    }
  }
    
}
