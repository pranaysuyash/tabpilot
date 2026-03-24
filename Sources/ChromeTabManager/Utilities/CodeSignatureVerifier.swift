import Foundation
import Security

enum CodeSignatureVerifier {

    static func verifyCurrentProcessSignature() -> Bool {
        var code: SecCode?
        let selfStatus = SecCodeCopySelf([], &code)
        guard selfStatus == errSecSuccess, let code else {
            return false
        }

        let validityStatus = SecCodeCheckValidity(code, [], nil)
        return validityStatus == errSecSuccess
    }

    static func signingTeamIdentifier() -> String? {
        let executablePath = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        let executableURL = URL(fileURLWithPath: executablePath) as CFURL

        var staticCode: SecStaticCode?
        let staticStatus = SecStaticCodeCreateWithPath(executableURL, [], &staticCode)
        guard staticStatus == errSecSuccess, let code = staticCode else {
            return nil
        }

        var infoRef: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &infoRef)
        guard infoStatus == errSecSuccess,
              let info = infoRef as? [CFString: Any],
              let team = info[kSecCodeInfoTeamIdentifier] as? String else {
            return nil
        }

        return team
    }
}
