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

struct ChatView: View {
  @ObservedObject var model: BlabberModel

  /// `true` if the message text field is focused.
  @FocusState var focused: Bool

  /// The message that the user has typed.
  @State var message = ""

  /// The last error message that happened.
  @State var lastErrorMessage = "" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false

  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    VStack {
      ScrollView(.vertical) {
        ScrollViewReader { reader in
          ForEach($model.messages) { message in
            MessageView(message: message, myUser: model.username)
          }
          .onChange(of: model.messages.count) { _ in
            guard let last = model.messages.last else { return }

            withAnimation(.easeOut) {
              reader.scrollTo(last.id, anchor: .bottomTrailing)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      HStack {
        Button(action: {
          Task {
            do {
              try await model.shareLocation()
            } catch {
              lastErrorMessage = error.localizedDescription
            }
          }
        }, label: {
          Image(systemName: "location.circle.fill")
            .font(.title)
            .foregroundColor(Color.gray)
        })

        Button(action: {
          Task {
            do {
              let countdownMessage = message
              message = ""
              try await model.countdown(to: countdownMessage)
            } catch {
              lastErrorMessage = error.localizedDescription
            }
          }
        }, label: {
          Image(systemName: "timer")
            .font(.title)
            .foregroundColor(Color.gray)
        })

        TextField(text: $message, prompt: Text("Message")) {
          Text("Enter message")
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .focused($focused)
        .onSubmit {
          Task {
            try await model.say(message)
            message = ""
          }
          focused = true
        }

        Button(action: {
          Task {
            try await model.say(message)
            message = ""
          }
        }, label: {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title)
        })
      }
    }
    .padding()
    .onAppear {
      focused = true
    }
    .alert("Error", isPresented: $isDisplayingError, actions: {
      Button("Close", role: .cancel) {
        self.presentationMode.wrappedValue.dismiss()
      }
    }, message: {
      Text(lastErrorMessage)
    })
    .task {
      do {
        try await model.chat()
      } catch {
        lastErrorMessage = error.localizedDescription
      }
    }
  }
}
