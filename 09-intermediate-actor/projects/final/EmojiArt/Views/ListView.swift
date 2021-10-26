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

struct ListView: View {
  @EnvironmentObject var model: EmojiArtModel

  /// The latest error message.
  @State var lastErrorMessage = "None" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false

  @State var isDisplayingPreview = false
  @State var selected: ImageFile?

  var columns: [GridItem] = [
    GridItem(.flexible(minimum: 50, maximum: 120)),
    GridItem(.flexible(minimum: 50, maximum: 120)),
    GridItem(.flexible(minimum: 50, maximum: 120))
  ]

  var body: some View {
    VStack {
      Text("Emoji Art")
        .font(.custom("YoungSerif-Regular", size: 36))
        .foregroundColor(.pink)

      GeometryReader { geo in
        ScrollView {
          LazyVGrid(columns: columns, spacing: 2) {
            ForEach(model.imageFeed) { image in
              VStack(alignment: .center) {
                Button(action: {
                  selected = image
                }, label: {
                  ThumbImage(file: image)
                    .frame(width: geo.size.width / 3 * 0.75, height: geo.size.width / 3 * 0.75)
                    .clipped()
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                })

                Text(image.name)
                  .fontWeight(.bold)
                  .font(.caption)
                  .foregroundColor(.gray)
                  .lineLimit(2)

                Text(String(format: "$%.2f", image.price))
                  .font(.caption2)
                  .foregroundColor(.black)
              }
              .frame(height: geo.size.width / 3 + 20, alignment: .top)
            }
          }
        }
      }
      .alert("Error", isPresented: $isDisplayingError, actions: {
        Button("Close", role: .cancel) { }
      }, message: {
        Text(lastErrorMessage)
      })
      .sheet(isPresented: $isDisplayingPreview, onDismiss: {
        selected = nil
      }, content: {
        if let selected = selected {
          DetailsView(file: selected)
        }
      })
      .onChange(of: selected) { newValue in
        isDisplayingPreview = newValue != nil
      }

      BottomToolbar()
    }
  }
}
