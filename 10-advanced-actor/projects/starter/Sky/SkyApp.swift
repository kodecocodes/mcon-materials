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

import SwiftUI
import Combine

@main
struct SkyApp: App {
  @ObservedObject
  var scanModel = ScanModel(total: 20, localName: UIDevice.current.name)

  @State var isScanning = false

  /// The last error message that happened.
  @State var lastMessage = "" {
    didSet {
      isDisplayingMessage = true
    }
  }
  @State var isDisplayingMessage = false

  var body: some Scene {
    WindowGroup {
      NavigationView {
        VStack {
          TitleView(isAnimating: .constant(false))

          Text("Scanning deep space")
            .font(.subheadline)

          ScanningView(
            total: $scanModel.total,
            completed: $scanModel.completed,
            perSecond: $scanModel.countPerSecond,
            scheduled: $scanModel.scheduled
          )

          Button(action: {
            Task {
              isScanning = true
              do {
                let start = Date().timeIntervalSinceReferenceDate
                try await scanModel.runAllTasks()
                let end = Date().timeIntervalSinceReferenceDate
                lastMessage = String(
                  format: "Finished %d scans in %.2f seconds.",
                  scanModel.total,
                  end - start
                )
              } catch {
                lastMessage = error.localizedDescription
              }
              isScanning = false
            }
          }, label: {
            HStack(spacing: 6) {
              if isScanning { ProgressView() }
              Text("Engage systems")
            }
          })
          .buttonStyle(.bordered)
          .disabled(isScanning)
        }
        .alert("Message", isPresented: $isDisplayingMessage, actions: {
          Button("Close", role: .cancel) { }
        }, message: {
          Text(lastMessage)
        })
        .padding()
        .statusBar(hidden: true)
      }
    }
  }
}
