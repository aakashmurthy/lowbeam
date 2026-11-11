import SwiftUI

enum LBTheme {
    static let accent = Color(red: 0.20, green: 0.82, blue: 0.98)
    static let accentSoft = Color(red: 0.20, green: 0.82, blue: 0.98).opacity(0.16)
    static let card = Color.white.opacity(0.055)
    static let cardStrong = Color.white.opacity(0.085)
    static let stroke = Color.white.opacity(0.10)
    static let muted = Color.white.opacity(0.58)
    static let background = LinearGradient(
        colors: [
            Color(red: 0.025, green: 0.035, blue: 0.055),
            Color(red: 0.04, green: 0.055, blue: 0.085),
            Color(red: 0.02, green: 0.025, blue: 0.04),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func color(_ name: String) -> Color {
        switch name.lowercased() {
        case "systemred", "red": return .red
        case "systemorange", "orange": return .orange
        case "systemgreen", "green": return .green
        case "systemteal", "teal": return .teal
        case "systemcyan", "cyan": return .cyan
        case "systemyellow", "yellow": return .yellow
        case "systempurple", "purple": return .purple
        case "systemindigo", "indigo": return .indigo
        case "systempink", "pink": return .pink
        case "systemmint", "mint": return .mint
        default: return accent
        }
    }
}

struct LBCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LBTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LBTheme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func lbCard(padding: CGFloat = 16) -> some View {
        modifier(LBCard(padding: padding))
    }
}

struct LBIcon: View {
    let name: String
    var color: Color = LBTheme.accent
    var size: CGFloat = 20
    var padding: CGFloat = 12

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size + padding * 2, height: size + padding * 2)
            .background(
                RoundedRectangle(cornerRadius: (size + padding * 2) * 0.32, style: .continuous)
                    .fill(color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: (size + padding * 2) * 0.32, style: .continuous)
                    .stroke(color.opacity(0.24), lineWidth: 1)
            )
    }
}

struct LBHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LBTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LBEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            LBIcon(name: icon, size: 26, padding: 16)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LBTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .lbCard()
    }
}
