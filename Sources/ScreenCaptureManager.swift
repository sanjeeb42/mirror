import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreGraphics

public protocol ScreenCaptureDelegate: AnyObject {
    func didCaptureSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

public class ScreenCaptureManager: NSObject, SCStreamOutput, SCStreamDelegate {
    public weak var delegate: ScreenCaptureDelegate?
    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "com.macmirror.screencapture.output", qos: .userInteractive)
    
    public override init() {
        super.init()
    }
    
    /// Requests screen recording permissions if not already authorized
    public static func checkAndRequestPermissions() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }
    
    /// Starts capturing the primary display at target resolution and framerate
    public func startCapture(width: Int = 1280, height: Int = 720, fps: Int = 30) async throws {
        guard ScreenCaptureManager.checkAndRequestPermissions() else {
            throw NSError(domain: "ScreenCaptureManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Screen Recording permission was not granted in System Settings."
            ])
        }
        
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = shareableContent.displays.first else {
            throw NSError(domain: "ScreenCaptureManager", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "No display found to capture."
            ])
        }
        
        // Exclude our own terminal/app process if possible, or capture the entire display
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.queueDepth = 5
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        config.showsCursor = true
        
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        
        try await newStream.startCapture()
        self.stream = newStream
        print("✓ ScreenCaptureKit started capturing at \(width)x\(height) @ \(fps) FPS")
    }
    
    /// Stops the capture stream and releases resources
    public func stopCapture() async {
        guard let stream = self.stream else { return }
        do {
            try await stream.stopCapture()
            print("✓ ScreenCaptureKit capture stopped")
        } catch {
            print("✗ Error stopping capture: \(error)")
        }
        self.stream = nil
    }
    
    // MARK: - SCStreamOutput
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        delegate?.didCaptureSampleBuffer(sampleBuffer)
    }
    
    // MARK: - SCStreamDelegate
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("✗ ScreenCaptureKit stream stopped with error: \(error)")
    }
}
