import Foundation

@MainActor
final class ScriptRunner: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var finished = false
    @Published private(set) var current = "Ready"
    @Published private(set) var progress = 0.0
    @Published private(set) var log: [String] = []
    @Published private(set) var sentCount = 0
    @Published private(set) var lastError: String?

    private var stopRequested = false
    private var task: Task<Void, Never>?

    func start(
        action: ScriptAction,
        pack: ScriptPack,
        store: PackStore,
        connection: ConnectionManager,
        loop: Bool,
        speed: Double
    ) {
        guard !isRunning else { return }
        stopRequested = false
        isRunning = true
        finished = false
        current = action.title
        progress = 0
        log = []
        sentCount = 0
        lastError = nil

        task = Task { @MainActor [weak self] in
            await self?.run(
                action: action,
                pack: pack,
                store: store,
                connection: connection,
                loop: loop,
                speed: max(0.25, min(speed, 4.0))
            )
        }
    }

    func stop() {
        guard isRunning, !stopRequested else { return }
        stopRequested = true
        logLine("Stop requested. Sending cleanup steps...")
    }

    func reset() {
        guard !isRunning else { return }
        finished = false
        current = "Ready"
        progress = 0
        log = []
        sentCount = 0
        lastError = nil
    }

    private func run(
        action: ScriptAction,
        pack: ScriptPack,
        store: PackStore,
        connection: ConnectionManager,
        loop: Bool,
        speed: Double
    ) async {
        let modules = Set((connection.vehicle?.modules ?? Vehicle.demo.modules).map { $0.uppercased() })
        let repeatCount = max(1, action.repeatCount ?? 1)
        let total = max(1, action.sequence.count * repeatCount)
        var index = 0

        logLine("\(pack.title) — \(action.title)")
        logLine("Target: \(connection.vehicle?.name ?? "Demo vehicle")")

        repeat {
            for _ in 0..<repeatCount {
                for step in action.sequence {
                    if stopRequested { break }
                    index += 1
                    current = step.command
                    progress = min(1.0, Double(index) / Double(total))
                    await execute(step, store: store, connection: connection, modules: modules, speed: speed)
                }
                if stopRequested { break }
            }
            if !loop { break }
            if stopRequested { break }
            logLine("Looping \(action.title)")
        } while !stopRequested

        let cleanup = action.disable ?? []
        if !cleanup.isEmpty {
            current = "Cleanup"
            logLine("Cleanup: \(cleanup.count) step(s)")
            for step in cleanup {
                await execute(step, store: store, connection: connection, modules: modules, speed: speed)
            }
        }

        isRunning = false
        finished = true
        current = stopRequested ? "Stopped" : "Finished"
        logLine(current)
    }

    private func execute(
        _ step: ScriptStep,
        store: PackStore,
        connection: ConnectionManager,
        modules: Set<String>,
        speed: Double
    ) async {
        let targets = store.resolve(
            command: step.command,
            groups: step.group,
            modules: modules,
            sgbdHint: step.sgbd
        )
        guard !targets.isEmpty else {
            logLine("No module matched \(step.command) \(step.group.joined(separator: "/"))")
            return
        }

        for target in targets {
            if stopRequested { break }
            do {
                let payload = try store.encode(
                    sgbd: target.sgbd,
                    action: target.entry,
                    params: step.params ?? [:]
                )
                let frame = try Encoder.frame(
                    payload: payload,
                    dest: target.bundle.addressByte
                )
                if connection.canSend {
                    if let response = try await connection.send(frame: frame) {
                        logLine("\(target.sgbd) RX \(Hex.string(response))")
                    } else {
                        logLine("\(target.sgbd) TX \(Hex.string(payload)) (no response)")
                    }
                } else {
                    logLine("\(target.sgbd) demo \(Hex.string(payload))")
                }
                sentCount += 1
            } catch {
                lastError = error.localizedDescription
                logLine("\(target.sgbd) error: \(error.localizedDescription)")
            }
        }

        let delay = max(0, step.delayMs ?? 90)
        let nanoseconds = UInt64((Double(delay) / speed) * 1_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    private func logLine(_ message: String) {
        log.append(message)
        if log.count > 300 {
            log.removeFirst(log.count - 300)
        }
    }

    deinit {
        task?.cancel()
    }
}
