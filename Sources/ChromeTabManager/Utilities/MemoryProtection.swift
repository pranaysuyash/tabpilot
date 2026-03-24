import Foundation
import Darwin

enum MemoryProtection {

    static func secureWipe(_ data: inout Data) {
        guard !data.isEmpty else { return }
        data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            memset_s(baseAddress, rawBuffer.count, 0, rawBuffer.count)
        }
        data.removeAll(keepingCapacity: false)
    }

    static func secureWipe(_ bytes: inout [UInt8]) {
        guard !bytes.isEmpty else { return }
        bytes.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            memset_s(baseAddress, buffer.count, 0, buffer.count)
        }
        bytes.removeAll(keepingCapacity: false)
    }

    static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<lhs.count {
            diff |= lhs[i] ^ rhs[i]
        }
        return diff == 0
    }
}
