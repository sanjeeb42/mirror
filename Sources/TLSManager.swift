import Foundation
import Security

public enum TLSManager {
    /// Generates or loads a self-signed TLS certificate and private key in PKCS#12 (.p12) format for LAN usage
    public static func getOrCreateIdentity(ipAddress: String) -> SecIdentity? {
        let certDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mac_mirror")
        try? FileManager.default.createDirectory(at: certDir, withIntermediateDirectories: true)
        
        let p12URL = certDir.appendingPathComponent("mirror_cert.p12")
        let certURL = certDir.appendingPathComponent("mirror_cert.crt")
        let keyURL = certDir.appendingPathComponent("mirror_cert.key")
        let password = "mirror_password"
        
        if FileManager.default.fileExists(atPath: p12URL.path) {
            if let identity = loadIdentity(from: p12URL, password: password) {
                return identity
            }
        }
        
        // Generate self-signed certificate with IP SAN using OpenSSL (pre-installed on macOS)
        let configURL = certDir.appendingPathComponent("openssl.cnf")
        let cnfContent = """
        [req]
        default_bits = 2048
        prompt = no
        default_md = sha256
        distinguished_name = dn
        x509_extensions = v3_req

        [dn]
        C = US
        ST = Local
        L = Local
        O = MacMirror
        CN = \(ipAddress)

        [v3_req]
        subjectAltName = @alt_names

        [alt_names]
        IP.1 = \(ipAddress)
        IP.2 = 127.0.0.1
        DNS.1 = localhost
        """
        try? cnfContent.write(to: configURL, atomically: true, encoding: .utf8)
        
        let genKeyCmd = "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout '\(keyURL.path)' -out '\(certURL.path)' -config '\(configURL.path)' -extensions v3_req"
        let p12Cmd = "openssl pkcs12 -export -out '\(p12URL.path)' -inkey '\(keyURL.path)' -in '\(certURL.path)' -passout pass:\(password)"
        
        _ = runShell(genKeyCmd)
        _ = runShell(p12Cmd)
        
        return loadIdentity(from: p12URL, password: password)
    }
    
    private static func loadIdentity(from url: URL, password: String) -> SecIdentity? {
        guard let p12Data = try? Data(contentsOf: url) else { return nil }
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)
        guard status == errSecSuccess, let items = rawItems as? [[String: Any]], let first = items.first else {
            return nil
        }
        guard let rawIdentity = first[kSecImportItemIdentity as String],
              CFGetTypeID(rawIdentity as CFTypeRef) == SecIdentityGetTypeID() else {
            return nil
        }
        return (rawIdentity as! SecIdentity)
    }
    
    private static func runShell(_ command: String) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}
