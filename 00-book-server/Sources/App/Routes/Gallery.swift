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
    self.checksum = UUID().uuidString
  }

  let name: String
  let url: String
  let price: Double
  let checksum: String
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
    gradient = [.cyan, .systemIndigo]

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
