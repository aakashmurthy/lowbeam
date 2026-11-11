import SwiftUI

struct GarageView: View {
    @EnvironmentObject private var connection: ConnectionManager
    @EnvironmentObject private var scripts: ScriptStore
    @Binding var showConnect: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LBHeader(
                        title: "Garage",
                        subtitle: connection.vehicle == nil
                            ? "Connect a vehicle or explore the demo."
                            : "Your car is ready."
                    )

                    if let vehicle = connection.vehicle {
                        connected(vehicle)
                    } else {
                        disconnected
                    }

                    adapterCard
                    safetyCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(LBTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showConnect = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(LBTheme.accent)
                    }
                }
            }
        }
    }

    private func connected(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                LBIcon(name: "car.fill", size: 26, padding: 15)
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.name)
                        .font(.title3.bold())
                    Text("\(vehicle.series) · \(vehicle.chassis)")
                        .font(.subheadline)
                        .foregroundStyle(LBTheme.muted)
                }
                Spacer()
                Circle()
                    .fill(Color.green)
                    .frame(width: 9, height: 9)
                    .shadow(color: .green.opacity(0.8), radius: 6)
            }

            HStack(spacing: 8) {
                infoPill("VIN", vehicle.vin)
                infoPill("Modules", "\(vehicle.modules.count)")
                infoPill("Link", connection.mode.title)
            }

            if !vehicle.vin.isEmpty && vehicle.vin != "Not available" {
                Text(vehicle.vin)
                    .font(.caption.monospaced())
                    .foregroundStyle(LBTheme.muted)
                    .textSelection(.enabled)
            }

            Divider().overlay(LBTheme.stroke)

            VStack(alignment: .leading, spacing: 10) {
                Text("Detected modules")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LBTheme.muted)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 78), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(vehicle.modules, id: \.self) { module in
                        Text(module)
                            .font(.caption2.monospaced().weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(LBTheme.cardStrong)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LBTheme.stroke, lineWidth: 1))
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    showConnect = true
                } label: {
                    Label("Change adapter", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LBTheme.cardStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(role: .destructive) {
                    connection.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
        .lbCard(padding: 18)
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .fill(LBTheme.accent.opacity(0.14))
                    .frame(width: 132, height: 132)
                Circle()
                    .stroke(LBTheme.accent.opacity(0.24), lineWidth: 1)
                    .frame(width: 104, height: 104)
                Image(systemName: "headlight.high.beam.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(LBTheme.accent)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("Connect to your BMW")
                    .font(.title2.bold())
                Text("Use an ENET cable or Wi-Fi adapter. No account or subscription is required.")
                    .font(.subheadline)
                    .foregroundStyle(LBTheme.muted)
            }

            HStack(spacing: 10) {
                Button {
                    showConnect = true
                } label: {
                    Text("Connect vehicle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LBTheme.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    connection.adapter = AdapterCatalog.all[0]
                    connection.connectDemo()
                    showConnect = true
                } label: {
                    Text("Try demo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LBTheme.cardStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
        .lbCard(padding: 20)
    }

    private var adapterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Adapter")
                    .font(.headline)
                Spacer()
                Text(connection.isConnected ? "Connected" : "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(connection.isConnected ? .green : LBTheme.muted)
            }

            HStack(spacing: 14) {
                LBIcon(name: connection.adapter.symbol, size: 18, padding: 11)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.adapter.name).font(.subheadline.weight(.semibold))
                    Text(connection.adapter.detail)
                        .font(.caption)
                        .foregroundStyle(LBTheme.muted)
                }
                Spacer()
            }

            Button {
                showConnect = true
            } label: {
                Text("Choose adapter")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(LBTheme.cardStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .lbCard(padding: 16)
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Before you start", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            safetyLine("Park the car and keep the ignition on.")
            safetyLine("Do not run light shows on public roads.")
            safetyLine("Shows only send temporary commands; run cleanup or disconnect to return to normal.")
            safetyLine("Unplug the adapter when it is not in use.")
        }
        .lbCard(padding: 16)
    }

    private func safetyLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(LBTheme.muted).frame(width: 4, height: 4).padding(.top, 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(LBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func infoPill(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(LBTheme.muted)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(LBTheme.cardStrong)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
