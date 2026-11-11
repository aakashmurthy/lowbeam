import SwiftUI

struct WelcomeView: View {
    let onConnect: () -> Void
    let onOffline: () -> Void

    @State private var appeared = false
    @State private var glow = false

    var body: some View {
        ZStack {
            LBTheme.background.ignoresSafeArea()

            Circle()
                .fill(LBTheme.accent.opacity(glow ? 0.24 : 0.10))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 130, y: -250)

            Circle()
                .fill(Color.blue.opacity(glow ? 0.16 : 0.06))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: -150, y: 290)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer(minLength: 36)

                    HStack {
                        LBIcon(name: "lightbulb.max.fill", size: 26, padding: 15)
                        Spacer()
                        Text("LOWBEAM")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(3)
                            .foregroundStyle(LBTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Control lights on\nBMW, MINI, and\nRolls-Royce.")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .lineSpacing(-2)
                        Text("Play built-in light shows, inspect every coding action, and build your own scripts. No account. No paywall. No subscription.")
                            .font(.body)
                            .foregroundStyle(LBTheme.muted)
                    }

                    VStack(spacing: 12) {
                        feature(
                            icon: "car.fill",
                            title: "Connect or use a demo",
                            text: "ENET / Wi-Fi link or a complete offline demo vehicle."
                        )
                        feature(
                            icon: "play.circle.fill",
                            title: "Start light scripts",
                            text: "Nine built-in shows with cleanup steps that return the car to normal."
                        )
                        feature(
                            icon: "slider.horizontal.3",
                            title: "Build your own",
                            text: "Pick actions, set delays, choose icons and colors, then export a pack."
                        )
                    }

                    VStack(spacing: 12) {
                        Button(action: onConnect) {
                            Text("Connect vehicle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LBTheme.accent)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        Button(action: onOffline) {
                            Text("Browse offline")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LBTheme.cardStrong)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(LBTheme.stroke, lineWidth: 1)
                                )
                        }
                    }

                    Text("Shows are for parked vehicles only. Do not use on public roads. The vehicle returns to its original light state within about 10 seconds after a run ends.")
                        .font(.caption)
                        .foregroundStyle(LBTheme.muted)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func feature(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            LBIcon(name: icon, size: 18, padding: 11)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(LBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LBTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LBTheme.stroke, lineWidth: 1)
        )
    }
}
