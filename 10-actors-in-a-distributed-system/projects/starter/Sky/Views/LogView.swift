/// Copyright (c) 2022 Kodeco Inc.
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

struct LogView: View {
  @ObservedObject var scanModel: ScanModel

  var body: some View {
    VStack {
      Spacer()
      ScrollView {
        ScrollViewReader { proxy in
          logEntries(with: proxy)
        }
      }
      clearButton
    }
    .font(.caption)
  }

  private func logEntries(with proxy: ScrollViewProxy) -> some View {
    VStack {
      ForEach(scanModel.localTasksCompleted, id: \.self) {
        Text($0)
          .foregroundColor(.secondary)
      }
      .onChange(of: scanModel.localTasksCompleted) { newValue in
        proxy.scrollTo(newValue.last ?? "", anchor: .bottom)
      }
    }
  }

  @ViewBuilder
  private var clearButton: some View {
    if !scanModel.localTasksCompleted.isEmpty {
      Button("Clear Logs") {
        scanModel.localTasksCompleted = []
      }
      .buttonStyle(.bordered)
    }
  }
}

struct LogView_Previews: PreviewProvider {
  private static var previewModel: ScanModel = {
    let model = ScanModel(total: 20, localName: "Preview")
    model.localTasksCompleted = [
      "Task 1 Completed",
      "Task 2 Completed"
    ]
    return model
  }()
  static var previews: some View {
    VStack {
      Text("Other Content")
      LogView(scanModel: previewModel)
        .frame(height: 100)
    }
  }
}
