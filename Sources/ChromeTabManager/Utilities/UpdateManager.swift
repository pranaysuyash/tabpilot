import Foundation

#if canImport(Sparkle)
import Sparkle
import Observation

@Observable
@MainActor
final class UpdateManager: NSObject {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#else
@MainActor
final class UpdateManager: NSObject {
    func checkForUpdates() {
        // Sparkle is optional and not linked in current package configuration.
    }
}
#endif
