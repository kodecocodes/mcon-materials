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
