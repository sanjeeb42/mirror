import Foundation
import Network
import Security

public class LocalWebServer {
    private var listener: NWListener?
    private let port: UInt16
    private let webViewerPath: URL
    private let ipAddress: String
    
    public init(port: UInt16 = 8443, ipAddress: String, webViewerPath: URL) {
        self.port = port
        self.ipAddress = ipAddress
        self.webViewerPath = webViewerPath
    }
    
    public func start() throws {
        // Setup TLS parameters
        guard let identity = TLSManager.getOrCreateIdentity(ipAddress: ipAddress) else {
            throw NSError(domain: "LocalWebServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate TLS identity"])
        }
        
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
        
        if let secIdentity = sec_identity_create(identity) {
            sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, secIdentity)
        }
        
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        // Allow connections from any network interface (Wi-Fi, hotspot, LAN)
        parameters.prohibitedInterfaceTypes = []
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "LocalWebServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid port"])
        }
        
        listener = try NWListener(using: parameters, on: nwPort)
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✓ HTTPS Server listening on https://\(self.ipAddress):\(self.port)")
            case .failed(let error):
                print("✗ Server failed: \(error)")
            default:
                break
            }
        }
        
        listener?.start(queue: .global(qos: .userInitiated))
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        readRequest(connection: connection)
    }
    
    private func readRequest(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                if isComplete { connection.cancel() }
                return
            }
            
            guard let requestStr = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            self.processHttpRequest(requestStr: requestStr, rawData: data, connection: connection)
        }
    }
    
    private func processHttpRequest(requestStr: String, rawData: Data, connection: NWConnection) {
        let lines = requestStr.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            connection.cancel()
            return
        }
        
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            connection.cancel()
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        if method == "GET" {
            handleGet(path: path, connection: connection)
        } else if method == "POST" {
            // Find body
            if let bodyRange = requestStr.range(of: "\r\n\r\n") {
                let body = String(requestStr[bodyRange.upperBound...])
                handlePost(path: path, body: body, connection: connection)
            } else {
                sendResponse(connection: connection, status: "400 Bad Request", contentType: "text/plain", body: Data("Malformed request".utf8))
            }
        } else {
            sendResponse(connection: connection, status: "405 Method Not Allowed", contentType: "text/plain", body: Data())
        }
    }
    
    private func handleGet(path: String, connection: NWConnection) {
        if path == "/api/candidates" {
            let candidates = SignalingServer.shared.drainOutgoingCandidates()
            if let json = try? JSONSerialization.data(withJSONObject: candidates) {
                sendResponse(connection: connection, status: "200 OK", contentType: "application/json", body: json)
            } else {
                sendResponse(connection: connection, status: "200 OK", contentType: "application/json", body: Data("[]".utf8))
            }
            return
        }
        
        var relativePath = path == "/" ? "index.html" : String(path.dropFirst())
        if relativePath.contains("?") {
            relativePath = String(relativePath.prefix(upTo: relativePath.firstIndex(of: "?")!))
        }
        
        let fileURL = webViewerPath.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? Data(contentsOf: fileURL) else {
            sendResponse(connection: connection, status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
            return
        }
        
        let contentType: String
        if relativePath.hasSuffix(".html") {
            contentType = "text/html; charset=utf-8"
        } else if relativePath.hasSuffix(".css") {
            contentType = "text/css; charset=utf-8"
        } else if relativePath.hasSuffix(".js") {
            contentType = "application/javascript; charset=utf-8"
        } else {
            contentType = "application/octet-stream"
        }
        
        sendResponse(connection: connection, status: "200 OK", contentType: contentType, body: content)
    }
    
    private func handlePost(path: String, body: String, connection: NWConnection) {
        guard let data = body.data(using: .utf8) else {
            sendResponse(connection: connection, status: "400 Bad Request", contentType: "text/plain", body: Data())
            return
        }
        
        if path == "/api/offer" {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sdp = json["sdp"] as? String,
                  let type = json["type"] as? String else {
                sendResponse(connection: connection, status: "400 Bad Request", contentType: "application/json", body: Data("{\"error\":\"Invalid SDP\"}".utf8))
                return
            }
            
            Task {
                if let answer = await SignalingServer.shared.onOfferReceived?(sdp, type) {
                    let resPayload: [String: Any] = ["sdp": answer.sdp, "type": answer.type]
                    if let resData = try? JSONSerialization.data(withJSONObject: resPayload) {
                        self.sendResponse(connection: connection, status: "200 OK", contentType: "application/json", body: resData)
                        return
                    }
                }
                self.sendResponse(connection: connection, status: "500 Internal Server Error", contentType: "application/json", body: Data("{\"error\":\"Failed to create answer\"}".utf8))
            }
        } else if path == "/api/candidate" {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let cand = json["candidate"] as? String {
                let mid = json["sdpMid"] as? String
                let mLineIndex = (json["sdpMLineIndex"] as? Int32) ?? 0
                SignalingServer.shared.onIceCandidateReceived?(cand, mid, mLineIndex)
            }
            sendResponse(connection: connection, status: "200 OK", contentType: "application/json", body: Data("{\"status\":\"ok\"}".utf8))
        } else {
            sendResponse(connection: connection, status: "404 Not Found", contentType: "text/plain", body: Data())
        }
    }
    
    private func sendResponse(connection: NWConnection, status: String, contentType: String, body: Data) {
        let headers = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r\n
        """
        guard let headerData = headers.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        var packet = headerData
        packet.append(body)
        
        connection.send(content: packet, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}
