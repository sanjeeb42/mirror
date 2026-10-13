import Foundation
import Network

func getLocalIP() -> String {
    var address: String = "127.0.0.1"
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            let flags = Int32(ptr!.pointee.ifa_flags)
            let addr = ptr!.pointee.ifa_addr.pointee
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ptr!.pointee.ifa_addr, socklen_t(addr.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: hostname)
                    if !ip.starts(with: "127.") {
                        address = ip
                        break
                    }
                }
            }
            ptr = ptr!.pointee.ifa_next
        }
        freeifaddrs(ifaddr)
    }
    return address
}

let localIP = getLocalIP()
let port: UInt16 = 8443
let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let webViewerDir = currentDir.appendingPathComponent("WebViewer")

print("==================================================")
print("          MAC SCREEN MIRROR SERVICE               ")
print("==================================================")
print("Local IP: \(localIP)")
print("Viewer Directory: \(webViewerDir.path)")

// Check & request screen capture permissions
if !ScreenCaptureManager.checkAndRequestPermissions() {
    print("⚠️  Screen Recording permission requested.")
    print("⚠️  If prompted, grant permission in System Settings > Privacy & Security > Screen & System Audio Recording")
}

let streamer = WebRTCStreamer()
streamer.startStream()

let captureManager = ScreenCaptureManager()
captureManager.delegate = streamer

Task {
    do {
        // Start capture at 720p 30 FPS
        try await captureManager.startCapture(width: 1280, height: 720, fps: 30)
    } catch {
        print("✗ Screen capture failed to start: \(error)")
    }
}

let server = LocalWebServer(port: port, ipAddress: localIP, webViewerPath: webViewerDir)

do {
    try server.start()
    print("\n>> Service is RUNNING!")
    print(">> Open Safari on your iPhone and visit:")
    print("   👉 https://\(localIP):\(port)")
    print("\n(Press Ctrl+C to stop)")
    
    // Register signal handlers for clean shutdown
    signal(SIGINT) { _ in
        print("\nStopping Mac Screen Mirror...")
        exit(0)
    }
    signal(SIGTERM) { _ in
        print("\nStopping Mac Screen Mirror...")
        exit(0)
    }
    
    dispatchMain()
} catch {
    print("Failed to start server: \(error)")
}
