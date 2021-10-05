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

import Foundation
import MultipeerConnectivity

/// Handles the discovery and data transport between systems.
class ScanTransport: NSObject {
  private let systemNetworkName = "skynet"
  private let localSystemName: MCPeerID

  let session: MCSession
  private let serviceAdvertiser: MCNearbyServiceAdvertiser
  private let serviceBrowser: MCNearbyServiceBrowser

  let localSystem: ScanSystem
  var taskModel: ScanModel?

  init(localSystem: ScanSystem) {
    localSystemName = MCPeerID(displayName: localSystem.name)
    serviceAdvertiser = MCNearbyServiceAdvertiser(
      peer: localSystemName,
      discoveryInfo: nil,
      serviceType: systemNetworkName
    )
    serviceBrowser = MCNearbyServiceBrowser(peer: localSystemName, serviceType: systemNetworkName)
    session = MCSession(peer: localSystemName, securityIdentity: nil, encryptionPreference: .required)

    self.localSystem = localSystem

    super.init()

    // Set up the service session.
    session.delegate = self

    // Set up service advertiser.
    serviceAdvertiser.delegate = self
    serviceAdvertiser.startAdvertisingPeer()

    // Set up service browser.
    serviceBrowser.delegate = self
    serviceBrowser.startBrowsingForPeers()
  }

  deinit {
    session.delegate = nil
    serviceAdvertiser.stopAdvertisingPeer()
    serviceAdvertiser.delegate = nil
    serviceBrowser.stopBrowsingForPeers()
    serviceBrowser.delegate = nil
  }

  func send(task: ScanTask, to recipient: String)
  async throws -> String {
    guard let targetPeer = session.connectedPeers.first(
      where: { $0.displayName == recipient }) else {
        throw "Peer '\(recipient)' not connected anymore."
      }
    let payload = try JSONEncoder().encode(task)
    try session.send(payload, toPeers: [targetPeer], with: .reliable)

    let networkRequest = TimeoutTask(seconds: 5) { () -> String in
      for await notification in
        NotificationCenter.default.notifications(named: .response) {
        if let response = notification.object as? TaskResponse,
          response.id == task.id {
          return "\(response.result) by \(recipient)"
        }
      }
      fatalError("Will never execute")
    }

    Task {
      for await notification in
        NotificationCenter.default.notifications(named: .disconnected) {
        if let peerName = notification.object as? String,
          peerName == recipient {
          await networkRequest.cancel()
        }
      }
    }

    return try await networkRequest.value
  }

  func send(response: TaskResponse, to peerID: MCPeerID) throws {
    guard session.connectedPeers.contains(peerID) else {
      throw "Peer '\(peerID)' not connected anymore."
    }

    let payload = try JSONEncoder().encode(response)
    try session.send(payload, toPeers: [peerID], with: .reliable)
  }
}

/// Handles changes in connectivity and asynchronously receiving data.
extension ScanTransport: MCSessionDelegate {
  /// Handles changes in session connectivity.
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    /// If it's a change in connectivity of the local node, don't broadcast it.
    guard peerID.displayName != localSystem.name else { return }

    switch state {
    case .notConnected:
      NotificationCenter.default.post(name: .disconnected, object: peerID.displayName)
    case .connected:
      NotificationCenter.default.post(name: .connected, object: peerID.displayName)
    default: break
    }
  }

  /// Handles incoming data.
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    let decoder = JSONDecoder()

    if let task = try? decoder.decode(ScanTask.self, from: data) {
      Task { [weak self] in
        guard let self = self,
          let taskModel = self.taskModel else { return }

        let result = try await taskModel.run(task)
        let response = TaskResponse(result: result, id: task.id)
        try self.send(response: response, to: peerID)
      }
    }

    if let response = try? decoder
      .decode(TaskResponse.self, from: data) {
      NotificationCenter.default.post(
        name: .response,
        object: response
      )
    }
  }
}

// MARK: - Service advertiser delegate implementation.

extension ScanTransport: MCNearbyServiceAdvertiserDelegate {
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    print("ScanTransport service advertiser failed: \(error.localizedDescription)")
  }

  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    // Automatically accept session invitations from all bonjour peers.
    invitationHandler(true, session)
  }
}

// MARK: - Service broswer delegate implementation.

extension ScanTransport: MCNearbyServiceBrowserDelegate {
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    print("ScanTransport service browse failed: \(error.localizedDescription)")
  }

  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
    // Automatically invite all found peers.
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
  }

  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    NotificationCenter.default.post(name: .disconnected, object: peerID.displayName)
  }
}

// MARK: - Required, unused `MCSessionDelegate` methods.

extension ScanTransport {
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}
