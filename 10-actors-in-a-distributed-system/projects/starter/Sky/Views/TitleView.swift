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

/// A view that displays a preset text animation.
struct TitleView: View {
  /// The title animates when this property is `true`.
  @Binding var isAnimating: Bool

  @State private var title = "s|2 |2k|0 |1y|3"
  @State private var titleIndex = 0

  @State private var timer = Timer.publish(every: 0.33, tolerance: 1, on: .main, in: .common)
    .autoconnect()

  static private let titleAnimation = [
    "s|2 |2k|0 |1y|3 |2n|1 |0e|1 |1t|2",
    "s|2 |2k|2 |0y|1 |3n|2 |1e|0 |1t|1",
    "s|1 |2k|2 |2y|0 |1n|3 |2e|1 |0t|1",
    "s|1 |1k|2 |2y|2 |0n|1 |3e|2 |1t|0",
    "s|0 |1k|1 |2y|2 |2n|0 |1e|3 |2t|1"
  ]

  private func updateTitle() {
    titleIndex += 1
    if titleIndex >= Self.titleAnimation.count {
      titleIndex = 0
    }
    title = Self.titleAnimation[titleIndex]
  }

  var body: some View {
    Text(title)
      .font(.custom("Datalegreya-Gradient", size: 36, relativeTo: .largeTitle))
      .onReceive(timer) { _ in
        if isAnimating {
          self.updateTitle()
        }
      }
  }
}
