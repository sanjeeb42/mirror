import Foundation
import WebRTC
import CoreMedia
import CoreVideo

public class WebRTCStreamer: NSObject, RTCPeerConnectionDelegate, ScreenCaptureDelegate {
    private var factory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var videoSource: RTCVideoSource?
    private var videoTrack: RTCVideoTrack?
    private let capturer = RTCVideoCapturer()
    
    public override init() {
        super.init()
        RTCInitializeSSL()
        
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        self.factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        
        // Video source configured for screen streaming
        self.videoSource = self.factory.videoSource(forScreenCast: true)
        self.videoTrack = self.factory.videoTrack(with: self.videoSource!, trackId: "mac-screen-video")
    }
    
    public func startStream() {
        SignalingServer.shared.clear()
        
        SignalingServer.shared.onOfferReceived = { [weak self] sdp, type in
            guard let self = self else { return nil }
            return await self.handleOffer(sdp: sdp, type: type)
        }
        
        SignalingServer.shared.onIceCandidateReceived = { [weak self] candidate, sdpMid, sdpMLineIndex in
            guard let self = self, let pc = self.peerConnection else { return }
            let rtcCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
            pc.add(rtcCandidate) { error in
                if let error = error {
                    print("✗ Error adding remote candidate: \(error)")
                }
            }
        }
    }
    
    private func handleOffer(sdp: String, type: String) async -> (sdp: String, type: String)? {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [] // Direct local LAN connection
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            print("✗ Failed to create peer connection")
            return nil
        }
        
        self.peerConnection = pc
        
        if let track = self.videoTrack {
            pc.add(track, streamIds: ["mac-screen-stream"])
        }
        
        let remoteDesc = RTCSessionDescription(type: .offer, sdp: sdp)
        
        do {
            try await pc.setRemoteDescription(remoteDesc)
            let answerConstraints = RTCMediaConstraints(mandatoryConstraints: [
                "OfferToReceiveVideo": "false",
                "OfferToReceiveAudio": "false"
            ], optionalConstraints: nil)
            
            let answerDesc = try await pc.answer(for: answerConstraints)
            try await pc.setLocalDescription(answerDesc)
            
            return (sdp: answerDesc.sdp, type: "answer")
        } catch {
            print("✗ WebRTC negotiation error: \(error)")
            return nil
        }
    }
    
    // MARK: - ScreenCaptureDelegate (Feeds ScreenCaptureKit frames into WebRTC)
    public func didCaptureSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let source = self.videoSource else {
            return
        }
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let nanoSeconds = Int64(CMTimeGetSeconds(timeStamp) * 1_000_000_000)
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let frame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: ._0, timeStampNs: nanoSeconds)
        source.capturer(self.capturer, didCapture: frame)
    }
    
    // MARK: - RTCPeerConnectionDelegate
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("[WebRTC] Signaling state: \(stateChanged.rawValue)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("[WebRTC] ICE Connection state: \(newState.rawValue)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("[WebRTC] ICE Gathering state: \(newState.rawValue)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("[WebRTC] Generated local candidate: \(candidate.sdp)")
        SignalingServer.shared.addOutgoingCandidate(
            candidate: candidate.sdp,
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex
        )
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
