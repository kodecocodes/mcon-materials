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
// Makes the default session requests not time out.
let liveURLSession: URLSession = {
  let configuration = URLSessionConfiguration.default
  configuration.timeoutIntervalForRequest = .infinity
  return URLSession(configuration: configuration)
}()

// Take the first command line parameter as the chat name.
guard let username = CommandLine.arguments.dropFirst().first else {
  print("Provide a username as the first command line argument.")
  exit(1)
}

Task {
  let url = URL(string: "http://localhost:8080/cli/chat?\(username)")!
  do {
    // Loop over the server response lines and print them.
    let (stream, _) = try await liveURLSession.bytes(from: url, delegate: nil)
    for try await line in stream.lines {
      print(line)
    }
  } catch {
    print(error.localizedDescription)
    exit(1)
  }
}

Task {
  let url = URL(string: "http://localhost:8080/cli/say")!
  
  // Loop over the lines in the standard input and send them to the server.
  for try await line in FileHandle.standardInput.bytes.lines {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = "[\(username)] \(line)".data(using: .utf8)

    do {
      _ = try await URLSession.shared.data(for: request, delegate: nil)
    } catch {
      print(error.localizedDescription)
      exit(1)
    }
  }
}

RunLoop.main.run()
