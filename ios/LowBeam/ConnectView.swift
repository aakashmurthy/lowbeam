import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var connection: ConnectionManager
    @Environment(\.dismiss) private var dismiss

    private var busy: Bool {
        switch connection.phase {
        case .connecting, .vehicle, .gateway, .modules:
            return true
        default:
            return false
        }
    }

    private var stage: Int {
        switch connection.phase {
        case .idle, .failed, .connecting: return 0
        case .vehicle: return 1
        case .gateway: return 2
        case .modules: return 3
        case .ready: return 4
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if connection.phase == .ready, let vehicle = connection.vehicle {
                        connected(vehicle)
                    } else {
                        header

                        if let error = connection.error {
                            errorBanner(error)
                        }

                        adapterSection(
                            title: "Recommended",
                            subtitle: "Wi-Fi, ENET, and demo connections.",
                            adapters: AdapterCatalog.recommended
                        )

                        adapterSection(
                            title: "Standard",
                            subtitle: "Bluetooth adapters are listed for reference. This build uses the ENET transport.",
                            adapters: AdapterCatalog.standard
                        )

                        if connection.adapter.kind == .enet {
                            enetFields
                        }

                        connectButton

                        if busy || connection.phase == .failed {
                            progressCard
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        if busy { connection.disconnect() }
                        dismiss()
                    }
                    .foregroundStyle(LBTheme.muted)
                }
            }
            .interactiveDismissDisabled(busy)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if connection.phase == .idle {
                connection.adapter = AdapterCatalog.all[0]
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose how to reach the car")
                .font(.title2.bold())
            Text("The demo works with no hardware and every built-in script. ENET uses a TCP link to a Wi-Fi adapter or cable.")
                .font(.subheadline)
                .foregroundStyle(LBTheme.muted)
        }
    }

    private func adapterSection(title: String, subtitle: String, adapters: [Adapter]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LBTheme.muted)
            }
            VStack(spacing: 8) {
                ForEach(adapters) { adapter in
                    adapterRow(adapter)
                }
            }
        }
    }

    private func adapterRow(_ adapter: Adapter) -> some View {
        let selected = connection.adapter.id == adapter.id
        let unsupported = adapter.kind == .bluetooth
        return Button {
            connection.adapter = adapter
        } label: {
            HStack(spacing: 12) {
                LBIcon(
                    name: adapter.symbol,
                    color: selected ? LBTheme.accent : LBTheme.muted,
                    size: 16,
                    padding: 10
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(adapter.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(unsupported ? LBTheme.muted : .white)
                    Text(adapter.detail)
                        .font(.caption)
                        .foregroundStyle(LBTheme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if unsupported {
                    Text("SOON")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(LBTheme.muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(LBTheme.cardStrong)
                        .clipShape(Capsule())
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LBTheme.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? LBTheme.accent.opacity(0.10) : LBTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? LBTheme.accent.opacity(0.45) : LBTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(busy || unsupported)
    }

    private var enetFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adapter address")
                .font(.headline)
            HStack(spacing: 10) {
                field("Host", text: $connection.host)
                field("Port", text: $connection.port)
                    .frame(width: 96)
            }
            Text("Default is 192.168.0.10:6801. Join the adapter's Wi-Fi network first.")
                .font(.caption)
                .foregroundStyle(LBTheme.muted)
        }
        .lbCard(padding: 14)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LBTheme.muted)
            TextField(label, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(label == "Port" ? .numberPad : .URL)
                .font(.subheadline.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(LBTheme.cardStrong)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var connectButton: some View {
        Button {
            connection.error = nil
            switch connection.adapter.kind {
            case .demo:
                connection.connectDemo()
            case .enet:
                connection.connectENet()
            case .bluetooth:
                break
            }
        } label: {
            HStack {
                if busy {
                    ProgressView().tint(.black)
                }
                Text(busy ? "Connecting..." : "Connect")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(LBTheme.accent)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy || connection.adapter.kind == .bluetooth)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Connection")
                    .font(.headline)
                Spacer()
                if busy {
                    ProgressView().tint(LBTheme.accent)
                }
            }

            VStack(spacing: 9) {
                stageRow(0, "Adapter link")
                stageRow(1, "Vehicle information")
                stageRow(2, "Gateway")
                stageRow(3, "Modules")
            }

            Text(connection.status)
                .font(.caption)
                .foregroundStyle(connection.phase == .failed ? .red : LBTheme.muted)

            if !connection.log.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(connection.log.suffix(5)), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(LBTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if connection.phase == .failed {
                Button {
                    connection.error = nil
                    connection.connectENet()
                } label: {
                    Text("Retry")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(LBTheme.cardStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .lbCard(padding: 16)
    }

    private func stageRow(_ index: Int, _ title: String) -> some View {
        let complete: Bool
        if connection.phase == .ready {
            complete = true
        } else {
            complete = index < stage
        }
        let active = busy && index == stage
        return HStack(spacing: 10) {
            Group {
                if complete {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if active {
                    ProgressView().tint(LBTheme.accent)
                } else {
                    Image(systemName: "circle").foregroundStyle(LBTheme.muted.opacity(0.5))
                }
            }
            .frame(width: 18)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(complete || active ? .white : LBTheme.muted)
            Spacer()
        }
    }

    private func connected(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.14))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 5) {
                Text("Connected")
                    .font(.title2.bold())
                Text(vehicle.name)
                    .font(.headline)
                    .foregroundStyle(LBTheme.muted)
                Text("\(vehicle.series) · \(vehicle.modules.count) modules")
                    .font(.subheadline)
                    .foregroundStyle(LBTheme.muted)
            }

            VStack(spacing: 8) {
                LabeledContent("VIN", value: vehicle.vin)
                LabeledContent("Chassis", value: vehicle.chassis)
                LabeledContent("Link", value: connection.mode.title)
            }
            .font(.subheadline)
            .lbCard(padding: 14)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(LBTheme.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                connection.disconnect()
            } label: {
                Text("Disconnect")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 28)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
