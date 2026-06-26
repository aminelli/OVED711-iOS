// Jailbreak Dettector

import Foundation
import UIKit
import Darwin

// MARK: - Jailbreak Detector

actor JailbreakDetector {
    struct Result: Sendable {
        let isJailbroken: Bool
        let triggers: [String]
    }

    func detect() -> Result {
        var triggers: [String] = []

        if checkSuspiciousPaths() { triggers.append("suspicious-paths") }
        if checkSandboxBreakout() { triggers.append("sandbox-breakout") }
        if checkDynamicLibraries() { triggers.append("dylib-injection") }
        if checkFork() { triggers.append("fork-allowed") }

        return Result(isJailbroken: !triggers.isEmpty, triggers: triggers)
    }

    // MARK: - Check 1: file/path sospetti

    private func checkSuspiciousPaths() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/etc/apt",
            "/usr/sbin/sshd",
            "/bin/bash",
            "/usr/bin/ssh",
            "/private/var/lib/apt"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Check 2: scrittura fuori sandbox

    private func checkSandboxBreakout() -> Bool {
        let testPath = "/private/jailbreak-test-\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Check 3: dylib iniettate (MobileSubstrate / Frida)

    private func checkDynamicLibraries() -> Bool {
        let suspicious = ["SubstrateLoader", "MobileSubstrate", "FridaGadget", "cynject"]
        let count = _dyld_image_count()
        for i in 0..<count {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name)
                if suspicious.contains(where: { imageName.contains($0) }) { return true }
            }
        }
        return false
    }

    // MARK: - Check 4: fork (app su App Store non può fare fork)

    private func checkFork() -> Bool {
        let pid = fork()
        if pid >= 0 {
            if pid > 0 { waitpid(pid, nil, 0) }
            return true // fork riuscita → jailbreak
        }
        return false
    }
}