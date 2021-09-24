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

/// Displays a list of stock symbols.
struct SymbolListView: View {
  let model: LittleJohnModel
  /// The list of stocks available on the server.
  @State var symbols: [String] = []
  /// The currently selected stocks.
  @State var selected: Set<String> = []
  /// Description of the latest error to display to the user.
  @State var lastErrorMessage = "" {
    didSet { isDisplayingError = true }
  }
  @State var isDisplayingError = false
  @State var isDisplayingTicker = false
  var body: some View {
    NavigationView {
      VStack {
        // Programatically push the live ticker view.
        NavigationLink(destination: TickerView(selectedSymbols: Array($selected.wrappedValue).sorted()).environmentObject(model),
                       isActive: $isDisplayingTicker) {
          EmptyView()
        }.hidden()
        // The list of stock symbols.
        List {
          Section(content: {
            if symbols.isEmpty {
              ProgressView().padding()
            }
            ForEach(symbols, id: \.self) { symbolName in
              Button(action: {
                if !selected.insert(symbolName).inserted {
                  selected.remove(symbolName)
                }
              }, label: {
                HStack {
                  HStack {
                    if selected.contains(symbolName) {
                      Image(systemName: "checkmark")
                    }
                  }
                  .frame(width: 20)
                  Text(symbolName)
                    .fontWeight(.bold)
                }
              })
            }
            .font(.custom("FantasqueSansMono-Regular", size: 18))
          }, header: {
            Label(" LittleJohn", systemImage: "chart.bar.xaxis")
              .foregroundColor(Color(uiColor: .systemGreen))
              .font(.custom("FantasqueSansMono-Regular", size: 42))
              .padding(.bottom, 20)
          })
        }
        .listStyle(PlainListStyle())
        .statusBar(hidden: true)
        .toolbar {
          Button("Live ticker") {
            if !selected.isEmpty {
              isDisplayingTicker = true
            }
          }
          .disabled(selected.isEmpty)
        }
        .alert("Error", isPresented: $isDisplayingError, actions: {
          Button("Close", role: .cancel) { }
        }, message: {
          Text(lastErrorMessage)
        })
        .padding(.horizontal)
      }
    }
  }
}
