import Foundation
import Network

enum TransportError: LocalizedError {
    case notConnected
    case cancelled
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .notConnected: return "The adapter is not connected."
        case .cancelled: return "The connection was cancelled."
        case .invalidPort: return "The port number is invalid."
        }
    }
}

/// HSFZ over TCP, used by ENET and several Wi-Fi adapters.
final class ENetTransport {
    private let queue = DispatchQueue(label: "dev.lowbeam.enet")
    private let lock = NSLock()
    private var connection: NWConnection?
    private var buffer = Data()
    private var pending: CheckedContinuation<[UInt8]?, Never>?

    func connect(host: String, port: UInt16) async throws {
        disconnect()
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw TransportError.invalidPort
        }
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: .tcp
        )
        self.connection = connection

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let stateLock = NSLock()
            var resumed = false
            func finish(_ result: Result<Void, Error>) {
                stateLock.lock()
                if resumed {
                    stateLock.unlock()
                    return
                }
                resumed = true
                stateLock.unlock()
                continuation.resume(with: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(Void()))
                case .failed(let error):
                    finish(.failure(error))
                case .cancelled:
                    finish(.failure(TransportError.cancelled))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }

        receiveLoop()
    }

    func send(frame: [UInt8]) async throws -> [UInt8]? {
        guard let connection else { throw TransportError.notConnected }
        let packet = hsfz(frame)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(packet), completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: Void())
                }
            })
        }
        return await waitForResponse(timeout: 0.8)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        lock.lock()
        buffer.removeAll()
        let waiter = pending
        pending = nil
        lock.unlock()
        waiter?.resume(returning: nil)
    }

    private func receiveLoop() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.lock.lock()
                self.buffer.append(data)
                self.lock.unlock()
                self.drain()
            }
            if error != nil || isComplete {
                self.finish(nil)
                return
            }
            self.receiveLoop()
        }
    }

    private func drain() {
        while true {
            lock.lock()
            guard buffer.count >= 6 else {
                lock.unlock()
                return
            }
            let header = [UInt8](buffer.prefix(4))
            let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            let total = 6 + Int(length)
            guard total >= 8, total <= 1024 * 1024, buffer.count >= total else {
                if total < 8 || total > 1024 * 1024 {
                    buffer.removeAll()
                }
                lock.unlock()
                return
            }
            let frame = [UInt8](buffer.prefix(total))
            buffer.removeFirst(total)
            let payload = Array(frame[8..<total])
            let waiter = pending
            pending = nil
            lock.unlock()
            waiter?.resume(returning: payload)
        }
    }

    private func waitForResponse(timeout: TimeInterval) async -> [UInt8]? {
        await withCheckedContinuation { (continuation: CheckedContinuation<[UInt8]?, Never>) in
            lock.lock()
            pending = continuation
            lock.unlock()
            queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish(nil)
            }
        }
    }

    private func finish(_ value: [UInt8]?) {
        lock.lock()
        let waiter = pending
        pending = nil
        lock.unlock()
        waiter?.resume(returning: value)
    }

    private func hsfz(_ payload: [UInt8]) -> [UInt8] {
        let length = payload.count + 2
        var packet: [UInt8] = [
            UInt8((length >> 24) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF),
            0x00,
            0x01,
        ]
        let source: UInt8
        if payload.count > 2 {
            source = payload[2] == 0xF1 ? 0xF4 : payload[2]
        } else {
            source = 0xF4
        }
        let destination = payload.count > 1 ? payload[1] : 0x40
        packet.append(source)
        packet.append(destination)
        packet.append(contentsOf: payload)
        return packet
    }

    deinit {
        connection?.cancel()
    }
}
