/// Copyright (c) 2023 Kodeco Inc.
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

struct LoadingView: View {
  @EnvironmentObject var model: EmojiArtModel

  /// The latest error message.
  @State var lastErrorMessage = "None" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false
  @State var progress = 0.0

  @Binding var isVerified: Bool

  let timer = Timer.publish(every: 0.2, on: .main, in: .common)
    .autoconnect()

  var body: some View {
    VStack(spacing: 4) {
      ProgressView("Verifying feed", value: progress)
        .tint(.gray)
        .font(.subheadline)

      if !model.imageFeed.isEmpty {
        Text("\(Int(progress * 100))%")
          .fontWeight(.bold)
          .font(.caption)
          .foregroundColor(.gray)
      }
    }
    .padding(.horizontal, 20)
    .task {
      guard model.imageFeed.isEmpty else { return }
      Task {
        do {
          try await ImageDatabase.shared.setUp()
          try await model.loadImages()
          try await model.verifyImages()
          withAnimation {
            isVerified = true
          }
        } catch {
          lastErrorMessage = error.localizedDescription
        }
      }
    }
    .alert("Error", isPresented: $isDisplayingError, actions: {
      Button("Close", role: .cancel) { }
    }, message: {
      Text(lastErrorMessage)
    })
    .onReceive(timer) { _ in
      guard !model.imageFeed.isEmpty else { return }

      Task {
        progress = await Double(model.verifiedCount) /
          Double(model.imageFeed.count)
      }
    }
  }
}
