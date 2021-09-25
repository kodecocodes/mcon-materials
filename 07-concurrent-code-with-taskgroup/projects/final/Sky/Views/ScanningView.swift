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

/// A view that displays the amount of total, completed, and avg. per second scan tasks.
struct ScanningView: View {
  @Binding var total: Int
  @Binding var completed: Int
  @Binding var perSecond: Double
  @Binding var scheduled: Int

  private func colorForAvg(_ num: Int) -> Color {
    switch num {
    case 0..<5: return .red
    case 5..<10: return .yellow
    case 10...: return .green
    default: return .gray
    }
  }

  var body: some View {
    VStack(alignment: .leading) {
      ProgressView("\(scheduled) scheduled", value: Double(scheduled), total: Double(total))
        .tint(colorForAvg(scheduled))
        .padding()

      ProgressView(String(format: "%.2f per sec.", perSecond), value: perSecond, total: 10)
        .tint(colorForAvg(Int(perSecond)))
        .padding()

      ProgressView("\(completed) tasks completed", value: min(1.0, Double(completed) / Double(total)))
        .tint(Color.blue)
        .padding()
    }
    .font(.callout)
    .padding()
  }
}
