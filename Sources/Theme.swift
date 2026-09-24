import SwiftUI

enum Theme {
    static let backgroundTop = Color(red: 0.025, green: 0.055, blue: 0.12)
    static let backgroundBottom = Color(red: 0.055, green: 0.085, blue: 0.16)
    static let accent = Color.cyan
    static let secondaryAccent = Color.blue
    static let card = Color.white.opacity(0.075)
    static let cardStrong = Color.white.opacity(0.11)
    static let stroke = Color.white.opacity(0.10)

    static let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    static func sky(for result: WeatherResult?) -> LinearGradient {
        let colors = result.map { skyColors(code: $0.current.weatherCode, isDay: $0.current.isDay == 1) }
            ?? [backgroundTop, backgroundBottom]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private static func skyColors(code: Int, isDay: Bool) -> [Color] {
        if !isDay { return code >= 95 ? [Color(red: 0.07, green: 0.04, blue: 0.16), Color(red: 0.03, green: 0.06, blue: 0.14)] : [Color(red: 0.03, green: 0.08, blue: 0.18), Color(red: 0.05, green: 0.14, blue: 0.24)] }
        switch code {
        case 0, 1: return [Color(red: 0.02, green: 0.40, blue: 0.72), Color(red: 0.06, green: 0.68, blue: 0.86)]
        case 2, 3: return [Color(red: 0.08, green: 0.28, blue: 0.48), Color(red: 0.18, green: 0.52, blue: 0.68)]
        case 45, 48: return [Color(red: 0.17, green: 0.23, blue: 0.31), Color(red: 0.35, green: 0.43, blue: 0.52)]
        case 51...67, 80...82: return [Color(red: 0.05, green: 0.17, blue: 0.30), Color(red: 0.12, green: 0.36, blue: 0.55)]
        case 71...77, 85, 86: return [Color(red: 0.26, green: 0.38, blue: 0.53), Color(red: 0.50, green: 0.66, blue: 0.78)]
        case 95...99: return [Color(red: 0.12, green: 0.08, blue: 0.28), Color(red: 0.27, green: 0.18, blue: 0.42)]
        default: return [backgroundTop, backgroundBottom]
        }
    }
}

extension View {
    func vipCard(padding: CGFloat = 17) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.065), in: Theme.cardShape)
            .overlay(Theme.cardShape.stroke(Theme.stroke, lineWidth: 1))
    }

    func glassButton() -> some View {
        self
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }
}
