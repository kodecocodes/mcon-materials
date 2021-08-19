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

struct FileDetails: View {
  let file: DownloadFile
  let isDownloading: Bool

  @Binding var isDownloadActive: Bool
  
  let downloadSingleAction: () -> Void
  let downloadWithUpdatesAction: () -> Void
  let downloadMultipleAction: () -> Void
  
  var body: some View {
    Section(content: {
      VStack(alignment: .leading) {
        HStack(spacing: 8) {
          if isDownloadActive {
            ProgressView()
          }
          
          Text(file.name)
            .font(.title3)
        }
        .padding(.leading, 8)
        
        Text(sizeFormatter.string(fromByteCount: Int64(file.size)))
          .font(.body)
          .foregroundColor(Color.indigo)
          .padding(.leading, 8)
        
        if !isDownloading {
          HStack {
            Button(action: downloadSingleAction, label: {
              Image(systemName: "arrow.down.app")
              Text("Silver")
            })
            .tint(Color.teal)
            
            Button(action: downloadWithUpdatesAction, label: {
              Image(systemName: "arrow.down.app.fill")
              Text("Gold")
            })
            .tint(Color.pink)
            
            Button(action: downloadMultipleAction, label: {
              Image(systemName: "dial.max.fill")
              Text("Cloud 9")
            })
            .buttonStyle(.borderedProminent)
            .tint(Color.purple)
          }
          .buttonStyle(.bordered)
          .font(.subheadline)
        }
      }
    }, header: {
      Label(" Download", systemImage: "arrow.down.app")
        .font(.custom("SerreriaSobria", size: 27))
        .foregroundColor(Color.accentColor)
        .padding(.bottom, 20)
    })
  }
}
