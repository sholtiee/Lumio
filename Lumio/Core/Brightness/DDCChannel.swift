import Foundation
import LumioKit

/// DDC/CI over one monitor's IOAVService. I²C is slow (tens of ms per
/// transaction) so everything runs on a private serial queue, and writes are
/// coalesced: dragging a slider sends only the latest value.
final class DDCChannel: @unchecked Sendable {
    private let service: AVService
    private let queue = DispatchQueue(label: "app.lumio.ddc", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: [UInt8: UInt16] = [:]
    private var flushing = false

    init(service: AVService) {
        self.service = service
    }

    func read(_ code: DDCProtocol.VCP) async -> (current: UInt16, max: UInt16)? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: performRead(code.rawValue))
            }
        }
    }

    func write(_ code: DDCProtocol.VCP, _ value: UInt16) {
        lock.lock()
        pending[code.rawValue] = value
        let shouldStart = !flushing
        flushing = true
        lock.unlock()
        if shouldStart { queue.async { [self] in flush() } }
    }

    private func flush() {
        while true {
            lock.lock()
            guard let (code, value) = pending.first else {
                flushing = false
                lock.unlock()
                return
            }
            pending[code] = nil
            lock.unlock()
            performWrite(code, value)
        }
    }

    // Monitors drop the odd packet, so writes are sent twice and reads retried —
    // the same approach MonitorControl found reliable on Apple Silicon.
    private func performWrite(_ code: UInt8, _ value: UInt16) {
        var packet = DDCProtocol.setPacket(code, value: value)
        for _ in 0..<2 {
            usleep(10_000)
            _ = IOAVServiceWriteI2C(service.ref, DDCProtocol.chipAddress, DDCProtocol.hostAddress, &packet, UInt32(packet.count))
        }
    }

    private func performRead(_ code: UInt8) -> (current: UInt16, max: UInt16)? {
        var request = DDCProtocol.getPacket(code)
        for _ in 0..<4 {
            usleep(10_000)
            guard IOAVServiceWriteI2C(service.ref, DDCProtocol.chipAddress, DDCProtocol.hostAddress, &request, UInt32(request.count)) == KERN_SUCCESS else {
                continue
            }
            usleep(50_000)
            var reply = [UInt8](repeating: 0, count: DDCProtocol.replyLength)
            guard IOAVServiceReadI2C(service.ref, DDCProtocol.chipAddress, DDCProtocol.hostAddress, &reply, UInt32(reply.count)) == KERN_SUCCESS else {
                continue
            }
            if let result = DDCProtocol.parseReply(reply, code: code) { return result }
            usleep(20_000)
        }
        return nil
    }
}
