import Foundation

// RECOVERY ADDON: additive service abstractions for future decomposition.
protocol URLNormalizingRecovery {
    func normalize(_ raw: String) -> String
}

struct URLNormalizerServiceRecovery: URLNormalizingRecovery {
    func normalize(_ raw: String) -> String {
        URLNormalizerRecovery.normalize(raw)
    }
}
