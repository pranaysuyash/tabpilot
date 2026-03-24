import Foundation
import Darwin

struct RuntimeSecurityReport {
    let debuggerAttached: Bool
    let suspiciousEnvironment: [String]
    let suspiciousLibraries: [String]
    let codeSignatureValid: Bool
    let generatedAt: Date

    var requiresMitigation: Bool {
        debuggerAttached || !suspiciousEnvironment.isEmpty || !suspiciousLibraries.isEmpty || !codeSignatureValid
    }
}

enum RuntimeProtection {

    static func evaluate() -> RuntimeSecurityReport {
        RuntimeSecurityReport(
            debuggerAttached: isDebuggerAttached(),
            suspiciousEnvironment: suspiciousEnvironmentVariables(),
            suspiciousLibraries: suspiciousLoadedLibraries(),
            codeSignatureValid: CodeSignatureVerifier.verifyCurrentProcessSignature(),
            generatedAt: Date()
        )
    }

    static func applyMitigations(for report: RuntimeSecurityReport) {
        guard report.requiresMitigation else {
            Logger.security.info("Runtime protection: no suspicious runtime signals detected")
            return
        }

        Logger.security.warning("Runtime protection: suspicious conditions detected")

        if report.debuggerAttached {
            Logger.security.warning("Runtime protection: debugger attached")
        }

        if !report.suspiciousEnvironment.isEmpty {
            Logger.security.warning("Runtime protection: suspicious env vars: \(report.suspiciousEnvironment.joined(separator: ","))")
        }

        if !report.suspiciousLibraries.isEmpty {
            Logger.security.warning("Runtime protection: suspicious libraries: \(report.suspiciousLibraries.joined(separator: ","))")
        }

        if !report.codeSignatureValid {
            Logger.security.error("Runtime protection: code signature check failed")
        }
    }

    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = mib.withUnsafeMutableBufferPointer { mibPointer in
            sysctl(mibPointer.baseAddress, 4, &info, &size, nil, 0)
        }

        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    private static func suspiciousEnvironmentVariables() -> [String] {
        let env = ProcessInfo.processInfo.environment
        let suspiciousKeys = [
            "DYLD_INSERT_LIBRARIES",
            "DYLD_LIBRARY_PATH",
            "DYLD_FRAMEWORK_PATH",
            "LD_PRELOAD"
        ]

        return suspiciousKeys.filter { key in
            if let value = env[key] {
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return false
        }
    }

    private static func suspiciousLoadedLibraries() -> [String] {
        let suspiciousMarkers = ["frida", "substrate", "cydia", "libhooker", "xposed", "gadget"]
        var hits: [String] = []

        let count = _dyld_image_count()
        for i in 0..<count {
            guard let cName = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: cName).lowercased()

            if suspiciousMarkers.contains(where: { imageName.contains($0) }) {
                hits.append(imageName)
            }
        }

        return hits
    }
}
