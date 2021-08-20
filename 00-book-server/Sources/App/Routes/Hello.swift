//
//  File.swift
//  File
//
//  Created by Marin Todorov on 8/12/21.
//

import Foundation
import Vapor

struct Hello {
  static func routes(_ app: Application) throws {
    app.get("hello") { req -> Response in
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .medium
      let date = formatter.string(from: Date())
      return Response(body: .init(data: "Hello! \(date)".data(using: .utf8)!))
    }
  }
}
