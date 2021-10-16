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

/// A chat message view.
struct MessageView: View {
  @Binding var message: Message
  let myUser: String

  private func color(for username: String?, myUser: String) -> Color {
    guard let username = username else {
      return Color.clear
    }
    return username == myUser ? Color.teal : Color.orange
  }

  var body: some View {
    HStack {
      if myUser == message.user {
        Spacer()
      }

      VStack(alignment: myUser == message.user ? .trailing : .leading) {
        if let user = message.user {
          HStack {
            if myUser != message.user {
              Text(user).font(.callout)
            }
          }
        }

        Text(message.message)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .overlay {
            RoundedRectangle(cornerRadius: 15)
              .strokeBorder(color(for: message.user, myUser: myUser), lineWidth: 1)
          }
      }

      if myUser != message.user && message.user != nil {
        Spacer()
      }
    }
    .padding(.vertical, 2)
    .frame(maxWidth: .infinity)
  }
}
