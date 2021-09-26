//
//  File.swift
//  
//
//  Created by Marin Todorov on 9/23/21.
//

import Foundation
import Vapor
import AppKit

struct ImageFile: Codable {
  init(nr: Int, name: String) {
    self.name = name.applyingTransform(.toUnicodeName, reverse: false)!
      .replacingOccurrences(of: "\\N", with: "")
      .components(separatedBy: CharacterSet.punctuationCharacters)
      .joined()
      .components(separatedBy: .whitespaces)
      .map({ $0.capitalized })
      .joined(separator: " ")

    self.url = "/gallery/image?\(nr)"
    self.price = Double.random(in: 5 ... 1000)
  }

  let name: String
  let url: String
  let price: Double
}

let emojis = ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🥲", "☺️", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "🚲", "🛵", "🏍", "🛺", "🚨", "🚍", "🚘", "🚖", "🚃", "🚋", "🚞"]

let images: [ImageFile] = {
  return emojis.enumerated().map { pair in
    cache[pair.offset] = image(nr: pair.offset)
    return ImageFile(nr: pair.offset, name: pair.element)
  }
}()

var cache = [Int: Data]()

func image(nr: Int) -> Data {
  let gradient: [NSColor]
  switch nr % 3 {
  case 0:
    gradient = [.systemPink, .systemTeal]
  case 1:
    gradient = [.systemRed, .systemYellow]
  case 2:
    gradient = [.systemGray, .systemIndigo]

  default: fatalError("Impossible")
  }
  let image = NSImage(gradientColors: gradient, imageSize: .init(width: 360, height: 650), includeDate: false)!
  image.lockFocus()
  (emojis[nr] as NSString).draw(at: NSPoint(x: 70, y: 250), withAttributes: [
    NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 200)
  ])
  image.unlockFocus()

  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
  let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
  let png = bitmapRep.representation(using: .png, properties: [:])!
  return png
}

struct Gallery {
  static func routes(_ app: Application) throws {

    app.get("gallery", "images") { req -> Response in
      let responseImages = [images + images + images].flatMap({ $0 }).shuffled()
      let responseData = try! JSONEncoder().encode(responseImages)
      return Response(body: .init(data: responseData))
    }

    app.get("gallery", "image") { req -> Response in

      guard let number = try? req.query.decode(Int.self), number % 10 > 0,
          number < images.count else {
            let responseData = try! JSONSerialization.data(withJSONObject: ["error": "File not found."], options: .prettyPrinted)
            return Response(body: .init(data: responseData))
          }

      let response = Response(status: .ok, body: .init(data: cache[number]!))
      response.headers.add(name: .contentType, value: "application/octet-stream")
      response.headers.add(name: .contentDisposition, value: "filename=\"\(number).tiff\"")
      return response
    }
  }
}
