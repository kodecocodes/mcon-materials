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

/// Displays a list of stocks and shows live price updates.
struct TickerView: View {
  let selectedSymbols: [String]
  @EnvironmentObject var model: LittleJohnModel
  @Environment(\.presentationMode) var presentationMode
  
  /// Description of the latest error to display to the user.
  @State var lastErrorMessage = "" {
    didSet { isDisplayingError = true }
  }
  @State var isDisplayingError = false

  var body: some View {
    List {
      Section(content: {
        // Show the list of selected symbols
        ForEach(model.tickerSymbols, id: \.name) { symbolName in
          HStack {
            Text(symbolName.name)
            Spacer()
              .frame(maxWidth: .infinity)
            Text(String(format: "%.3f", arguments: [symbolName.value]))
          }
        }
      }, header: {
        Label(" Live", systemImage: "clock.arrow.2.circlepath")
          .foregroundColor(Color.teal)
          .font(.custom("FantasqueSansMono-Regular", size: 48))
          .padding(.bottom, 20)
      })
    }
    .alert("Error", isPresented: $isDisplayingError, actions: {
      Button("Close", role: .cancel) { }
    }, message: {
      Text(lastErrorMessage)
    })
    .listStyle(PlainListStyle())
    .font(.custom("FantasqueSansMono-Regular", size: 18))
    .padding(.horizontal)

    .task {
      do {
        try await model.startTicker(selectedSymbols)
      } catch {
        lastErrorMessage = error.localizedDescription
      }
    }

  }
}
