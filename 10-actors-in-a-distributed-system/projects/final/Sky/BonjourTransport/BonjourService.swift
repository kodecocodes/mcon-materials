/// Copyright (c) 2023 Kodeco Inc.
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
import Distributed

/// Handles the discovery and data transport between systems.
final class BonjourService: NSObject {
  private let systemNetworkName = "skynet"
  let localSystemName: MCPeerID

  let session: MCSession
  private let serviceAdvertiser: MCNearbyServiceAdvertiser
  private let serviceBrowser: MCNearbyServiceBrowser

  weak var actorSystem: BonjourActorSystem?

  init(localName: String, actorSystem: BonjourActorSystem) {
    self.actorSystem = actorSystem
    let key = "peerID:\(localName)"
    if
      let data = UserDefaults.standard.data(forKey: key),
      let peerID = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
      localSystemName = peerID
    } else {
      localSystemName = MCPeerID(displayName: localName)
      do {
        let data = try NSKeyedArchiver.archivedData(withRootObject: localSystemName, requiringSecureCoding: true)
        UserDefaults.standard.set(data, forKey: key)
      } catch {
        print("Unable to archive peer ID")
      }
    }
    serviceAdvertiser = MCNearbyServiceAdvertiser(
      peer: localSystemName,
      discoveryInfo: nil,
      serviceType: systemNetworkName
    )
    serviceBrowser = MCNearbyServiceBrowser(peer: localSystemName, serviceType: systemNetworkName)
    session = MCSession(peer: localSystemName, securityIdentity: nil, encryptionPreference: .none)

    super.init()

    // Set up the service session.
    session.delegate = self

    // Set up service advertiser.
    serviceAdvertiser.delegate = self

    // Set up service browser.
    serviceBrowser.delegate = self

    Task {
      serviceBrowser.startBrowsingForPeers()
      serviceAdvertiser.startAdvertisingPeer()
    }
  }

  func send(
    invocation: BonjourInvocationEncoder,
    to recipient: String
  ) async throws -> TaskResponse {
    guard let targetPeer = session.connectedPeers.first(
      where: { $0.displayName == recipient }) else {
        throw "Peer '\(recipient)' not connected anymore."
      }

    let payload = try invocation.data
    try session.send(payload, toPeers: [targetPeer], with: .reliable)

    let networkRequest = TimeoutTask(seconds: 5) { () -> TaskResponse in
      for await notification in
        NotificationCenter.default.notifications(named: .response) {
        guard let response = notification.object as? TaskResponse,
          response.id == invocation.message.id else { continue }
        return response
      }
      fatalError("Will never execute")
    }

    Task {
      for await notification in
        NotificationCenter.default.notifications(named: .disconnected) {
        guard notification.object as? String == recipient else { continue }

        await networkRequest.cancel()
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

  deinit {
    session.delegate = nil
    serviceAdvertiser.stopAdvertisingPeer()
    serviceAdvertiser.delegate = nil
    serviceBrowser.stopBrowsingForPeers()
    serviceBrowser.delegate = nil
  }
}

/// Handles changes in connectivity and asynchronously receiving data.
extension BonjourService: MCSessionDelegate {
  /// Handles changes in session connectivity.
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    /// If it's a change in connectivity of the local node, don't broadcast it.
    guard peerID.displayName != localSystemName.displayName else { return }

    if [.connected, .notConnected].contains(state) {
      actorSystem?.connectivityChangedFor(
        deviceName: peerID.displayName,
        to: state == .connected
      )
    }
  }

  /// Handles incoming data.
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    let decoder = JSONDecoder()

    if let invocationMessage = try? decoder.decode(InvocationMessage.self, from: data) {
      actorSystem?.didReceiveInvocation(invocationMessage, data: data, from: peerID)
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

extension BonjourService: MCNearbyServiceAdvertiserDelegate {
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    print("ScanTransport service advertiser failed: \(error.localizedDescription)")
  }

  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    // Automatically accept session invitations from all bonjour peers.
    invitationHandler(true, session)
  }
}

// MARK: - Service browser delegate implementation.

extension BonjourService: MCNearbyServiceBrowserDelegate {
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    print("ScanTransport service browse failed: \(error.localizedDescription)")
  }

  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
    // Automatically invite all found peers.
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
  }

  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    actorSystem?.connectivityChangedFor(
      deviceName: peerID.displayName,
      to: false
    )
  }
}

// MARK: - Required, unused `MCSessionDelegate` methods.

extension BonjourService {
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}
