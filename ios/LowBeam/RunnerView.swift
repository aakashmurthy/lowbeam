import SwiftUI

struct RunnerView: View {
    let pack: ScriptPack
    let action: ScriptAction

    @EnvironmentObject private var store: PackStore
    @EnvironmentObject private var connection: ConnectionManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var runner = ScriptRunner()
    @State private var loop = false
    @State private var speed = 1.0
    @State private var started = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    controls
                    logCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle(pack.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if runner.isRunning {
                        Button {
                            runner.stop()
                        } label: {
                            Text("Stop")
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Button("Close") { dismiss() }
                            .foregroundStyle(LBTheme.muted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(connection.vehicle?.name ?? "Demo vehicle")
                        .font(.caption)
                        .foregroundStyle(LBTheme.muted)
                }
            }
            .interactiveDismissDisabled(runner.isRunning)
            .onAppear(perform: startIfNeeded)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                LBIcon(
                    name: action.icon,
                    color: LBTheme.color(action.color),
                    size: 24,
                    padding: 14
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.title3.bold())
                    Text(runner.isRunning ? "Running" : (runner.finished ? "Finished" : "Ready"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(runner.isRunning ? LBTheme.accent : LBTheme.muted)
                }
                Spacer()
            }

            ProgressView(value: runner.progress)
                .tint(LBTheme.accent)

            HStack {
                Text(runner.current)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(runner.sentCount) packets")
                    .font(.caption)
                    .foregroundStyle(LBTheme.muted)
            }

            if let error = runner.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .lbCard(padding: 18)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $loop) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loop show")
                        .font(.subheadline.weight(.semibold))
                    Text("Repeat until you stop it.")
                        .font(.caption)
                        .foregroundStyle(LBTheme.muted)
                }
            }
            .disabled(runner.isRunning)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Speed")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: "%.2f×", speed))
                        .font(.caption.monospaced())
                        .foregroundStyle(LBTheme.muted)
                }
                Slider(value: $speed, in: 0.5...2.5, step: 0.25)
                    .tint(LBTheme.accent)
                    .disabled(runner.isRunning)
            }

            if runner.finished {
                Button {
                    runner.reset()
                    started = false
                    startIfNeeded()
                } label: {
                    Label("Run again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LBTheme.cardStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if runner.isRunning {
                Button {
                    runner.stop()
                } label: {
                    Label("Stop and clean up", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.orange.opacity(0.16))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text("Cleanup steps run automatically when the show stops or finishes.")
                .font(.caption)
                .foregroundStyle(LBTheme.muted)
        }
        .lbCard(padding: 16)
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
                if runner.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .tint(LBTheme.accent)
                }
            }

            if runner.log.isEmpty {
                Text("No packets yet.")
                    .font(.caption)
                    .foregroundStyle(LBTheme.muted)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(runner.log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(LBTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .lbCard(padding: 16)
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        runner.start(
            action: action,
            pack: pack,
            store: store,
            connection: connection,
            loop: loop,
            speed: speed
        )
    }
}
