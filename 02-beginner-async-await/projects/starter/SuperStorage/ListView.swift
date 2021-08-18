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

/// The main list of available for download files.
struct ListView: View {
  let model: SuperStorageModel
  
  /// The file list.
  @State var files: [DownloadFile] = []
  
  /// The server status message.
  @State var status = ""
  
  /// The file to present for download.
  @State var selected = DownloadFile.empty {
    didSet {
      isDisplayingDownload = true
    }
  }
  @State var isDisplayingDownload = false

  /// The latest error message.
  @State var lastErrorMessage = "None" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false

  var body: some View {
    NavigationView {
      VStack {
        // Programatically push the file download view.
        NavigationLink(destination: DownloadView(file: selected).environmentObject(model),
                       isActive: $isDisplayingDownload) {
          EmptyView()
        }.hidden()
        
        // The list of files avalable for download.
        List {
          Section(content: {
            if files.isEmpty {
              ProgressView().padding()
            }
            
            ForEach(files) { file in
              Button(action: {
                selected = file
              }) {
                FileListItem(file: file)
              }
            }
          }, header: {
            Label(" SuperStorage", systemImage: "externaldrive.badge.icloud")
              .font(.custom("SerreriaSobria", size: 27))
              .foregroundColor(Color.accentColor)
              .padding(.bottom, 20)
          }, footer: {
            Text(status)
          })
        }
        .listStyle(InsetGroupedListStyle())
        .animation(.easeOut(duration: 0.33), value: files)
      }
      .alert("Error", isPresented: $isDisplayingError, actions: {
        Button("Close", role: .cancel) { }
      }, message: {
        Text(lastErrorMessage)
      })
    }
  }
}
