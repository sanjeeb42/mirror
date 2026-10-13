import Foundation
import Network

public class SignalingServer {
    public static let shared = SignalingServer()
    
    // Stored SDP offer handler (called when iPhone posts an offer)
    public var onOfferReceived: ((_ sdp: String, _ type: String) async -> (sdp: String, type: String)?)?
    public var onIceCandidateReceived: ((_ candidate: String, _ sdpMid: String?, _ sdpMLineIndex: Int32) -> Void)?
    
    // Server-side candidates to be fetched by the browser
    private var outgoingCandidates: [[String: Any]] = []
    private let lock = NSLock()
    
    public func addOutgoingCandidate(candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        lock.lock()
        defer { lock.unlock() }
        outgoingCandidates.append([
            "candidate": candidate,
            "sdpMid": sdpMid as Any,
            "sdpMLineIndex": sdpMLineIndex
        ])
    }
    
    public func drainOutgoingCandidates() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        let cands = outgoingCandidates
        outgoingCandidates.removeAll()
        return cands
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        outgoingCandidates.removeAll()
    }
}
