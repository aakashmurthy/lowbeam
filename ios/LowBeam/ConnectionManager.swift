import Foundation

@MainActor
final class ConnectionManager: ObservableObject {
    enum Mode {
        case demo
        case enet

        var title: String {
            switch self {
            case .demo: return "Demo vehicle"
            case .enet: return "Wi-Fi / ENET"
            }
        }
    }

    enum Phase: Int, Comparable {
        case idle = 0
        case connecting
        case vehicle
        case gateway
        case modules
        case ready
        case failed

        static func < (lhs: Phase, rhs: Phase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var status = ""
    @Published private(set) var log: [String] = []
    @Published private(set) var vehicle: Vehicle?
    @Published var error: String?
    @Published private(set) var mode: Mode = .demo
    @Published var adapter: Adapter = AdapterCatalog.all[0]
    @Published var host = "192.168.0.10"
    @Published var port = "6801"

    private let store: PackStore
    private var transport: ENetTransport?

    init(store: PackStore) {
        self.store = store
    }

    var isConnected: Bool { vehicle != nil }
    var canSend: Bool { mode == .enet && vehicle != nil }

    func connectDemo() {
        mode = .demo
        vehicle = nil
        error = nil
        log = []
        phase = .connecting
        status = "Preparing demo vehicle..."

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            self.logLine("Demo vehicle ready. No hardware is used.")
            self.phase = .vehicle
            self.status = "Reading vehicle information..."
            try? await Task.sleep(nanoseconds: 350_000_000)
            self.phase = .gateway
            self.status = "Scanning for gateway..."
            try? await Task.sleep(nanoseconds: 250_000_000)
            self.logLine("Gateway: demo")
            self.phase = .modules
            self.status = "Scanning for modules..."
            try? await Task.sleep(nanoseconds: 450_000_000)
            self.logLine("Found \(Vehicle.demo.modules.count) modules.")
            self.vehicle = Vehicle.demo
            self.phase = .ready
            self.status = "Scan complete. Found \(Vehicle.demo.modules.count) modules."
        }
    }

    func connectENet() {
        guard let portValue = UInt16(port) else {
            error = "Enter a valid TCP port."
            phase = .failed
            return
        }
        mode = .enet
        vehicle = nil
        error = nil
        log = []
        phase = .connecting
        status = "Connecting to \(adapter.name)..."

        Task { @MainActor in
            let transport = ENetTransport()
            self.transport = transport
            do {
                try await transport.connect(host: self.host, port: portValue)
                self.logLine("TCP link established to \(self.host):\(portValue).")
                self.phase = .vehicle
                self.status = "Reading vehicle information..."

                var modules: [String] = []
                var vin: String?
                let addresses = self.addresses()

                for address in addresses {
                    let ident = try Encoder.frame(
                        payload: [0x22, 0xF1, 0x50],
                        dest: address
                    )
                    if let response = try await transport.send(frame: ident),
                       let sgbd = self.sgbd(fromIdent: response),
                       !modules.contains(sgbd) {
                        modules.append(sgbd)
                        self.logLine("Module \(sgbd) responded at \(String(format: "%02X", address)).")
                    }

                    if vin == nil, !modules.isEmpty {
                        vin = try await self.readVIN(transport: transport, address: address)
                    }
                }

                self.phase = .gateway
                self.status = "Scanning for gateway..."
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.logLine("ENET is a direct vehicle link; no separate gateway was needed.")

                self.phase = .modules
                self.status = "Scanning for modules..."

                guard !modules.isEmpty else {
                    throw ConnectionError.noModules
                }

                let identity = self.identify(modules: modules)
                let vehicle = Vehicle(
                    name: identity.name,
                    vin: vin ?? "Not available",
                    chassis: identity.chassis,
                    series: identity.series,
                    modules: modules.sorted()
                )
                self.logLine("VIN: \(vehicle.vin)")
                self.logLine("Chassis: \(vehicle.series)")
                self.vehicle = vehicle
                self.phase = .ready
                self.status = "Scan complete. Found \(modules.count) modules."
            } catch {
                transport.disconnect()
                self.transport = nil
                self.phase = .failed
                self.error = error.localizedDescription
                self.status = "Connection failed."
                self.logLine("Error: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        transport?.disconnect()
        transport = nil
        vehicle = nil
        phase = .idle
        status = ""
        error = nil
        log = []
        mode = .demo
    }

    func send(frame: [UInt8]) async throws -> [UInt8]? {
        guard mode == .enet else { return nil }
        guard let transport else { throw TransportError.notConnected }
        return try await transport.send(frame: frame)
    }

    func logLine(_ message: String) {
        log.append(message)
        if log.count > 250 {
            log.removeFirst(log.count - 250)
        }
    }

    private func addresses() -> [UInt8] {
        let values = Set(store.bundles.values.map(\.addressByte))
        return values.sorted()
    }

    private func sgbd(fromIdent response: [UInt8]) -> String? {
        guard response.count >= 6,
              response[0] == 0x62,
              response[1] == 0xF1,
              response[2] == 0x50 else {
            return nil
        }
        let hex = response[3..<6]
            .map { String(format: "%02X", $0) }
            .joined()
        return store.sgbd(forHex: hex)
    }

    private func readVIN(transport: ENetTransport, address: UInt8) async throws -> String? {
        let frame = try Encoder.frame(payload: [0x22, 0xF1, 0x90], dest: address)
        guard let response = try await transport.send(frame: frame),
              response.count >= 20,
              response[0] == 0x62,
              response[1] == 0xF1,
              response[2] == 0x90 else {
            return nil
        }
        let bytes = Array(response[3..<20])
        let text = String(bytes: bytes, encoding: .ascii) ?? ""
        let cleaned = text.filter { $0.isLetter || $0.isNumber }
        guard cleaned.count >= 6, !cleaned.allSatisfy({ $0 == "0" }) else {
            return nil
        }
        return cleaned
    }

    private func identify(modules: [String]) -> (name: String, chassis: String, series: String) {
        let set = Set(modules)
        if set.contains("BDC_G11") {
            return ("BMW G-series", "G20", "3' G20")
        }
        if set.contains("BDC_G05") {
            return ("BMW G-series", "G05", "X5 G05")
        }
        if set.contains("FEM_20") || set.contains("REM_20") {
            return ("BMW F-series", "F30", "3' F30")
        }
        if set.contains("FRM3") || set.contains("FRM_70") {
            return ("BMW E-series", "E90", "3' E90")
        }
        if set.contains("LME38") {
            return ("BMW E-series", "E38", "7' E38")
        }
        return ("BMW vehicle", "BMW", "Detected vehicle")
    }
}

enum ConnectionError: LocalizedError {
    case noModules

    var errorDescription: String? {
        switch self {
        case .noModules:
            return "No modules responded. Check the ignition and make sure the OBD adapter is available."
        }
    }
}
