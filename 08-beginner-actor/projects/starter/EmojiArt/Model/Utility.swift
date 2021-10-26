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

import UIKit
import Accelerate

/// Easily throw generic errors with a text description.
extension String: LocalizedError {
  public var errorDescription: String? {
    return self
  }
}

extension Task where Success == Never, Failure == Never {
  /// Suspends the current task for at least the given duration in seconds.
  /// - Parameter seconds: The sleep duration in seconds.
  static func sleep(seconds: TimeInterval) async {
    await Task.sleep(UInt64(seconds * 1_000_000_000))
  }
}

struct ResizeError: Error { }

func resize(_ data: Data, to size: CGSize) throws -> UIImage {
  guard let cgImage = UIImage(data: data)?.cgImage,
    let colorSpace = cgImage.colorSpace else {
      throw ResizeError()
    }

  var format = vImage_CGImageFormat(
    bitsPerComponent: UInt32(cgImage.bitsPerComponent),
    bitsPerPixel: UInt32(cgImage.bitsPerPixel),
    colorSpace: Unmanaged.passRetained(colorSpace),
    bitmapInfo: cgImage.bitmapInfo,
    version: 0,
    decode: nil,
    renderingIntent: cgImage.renderingIntent
  )

  var buffer = vImage_Buffer()
  vImageBuffer_InitWithCGImage(&buffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))

  var destinationBuffer = try vImage_Buffer(width: Int(200), height: Int(200), bitsPerPixel: format.bitsPerPixel)

  defer { destinationBuffer.free() }

  _ = withUnsafePointer(to: buffer) { sourcePointer in
    vImageScale_ARGB8888(sourcePointer, &destinationBuffer, nil, vImage_Flags(kvImageNoFlags))
  }

  let destinationCGImage = vImageCreateCGImageFromBuffer(
    &buffer, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil
  )

  guard let destinationCGImage = destinationCGImage else {
    throw ResizeError()
  }

  return UIImage(cgImage: destinationCGImage.takeRetainedValue())
}
