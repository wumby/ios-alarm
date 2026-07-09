import SwiftUI

enum AppTheme {
    static let skyBlue = Color(red: 0.863, green: 0.933, blue: 1.0)
    static let peach = Color(red: 1.0, green: 0.824, blue: 0.690)
    static let warmOrange = Color(red: 1.0, green: 0.776, blue: 0.420)
    static let cream = Color(red: 1.0, green: 0.961, blue: 0.902)

    static let accent = Color(red: 0.969, green: 0.420, blue: 0.235)
    static let textPrimary = Color(red: 0.137, green: 0.125, blue: 0.219)
    static let textSecondary = Color(red: 0.435, green: 0.416, blue: 0.404)

    static let cardSurface = Color(red: 1.0, green: 0.980, blue: 0.949).opacity(0.92)
    static let cardBorder = Color(red: 0.90, green: 0.83, blue: 0.73).opacity(0.85)

    static let cardRadius: CGFloat = 22

    static var sunriseBackground: some View {
        SunriseBackground()
    }
}

struct SunriseBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.skyBlue, location: 0.0),
                        .init(color: AppTheme.peach, location: 0.44),
                        .init(color: AppTheme.warmOrange, location: 0.72),
                        .init(color: AppTheme.cream, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: AppTheme.accent.opacity(0.88), location: 0.0),
                                .init(color: AppTheme.accent.opacity(0.42), location: 0.28),
                                .init(color: AppTheme.accent.opacity(0.14), location: 0.52),
                                .init(color: .clear, location: 1.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 280, height: 280)
                    .blur(radius: 26)
                    .position(
                        x: proxy.size.width * 0.68,
                        y: proxy.size.height * 0.74
                    )

                NoiseOverlay()
                    .blendMode(.softLight)
                    .opacity(0.12)
            }
        }
        .ignoresSafeArea()
    }
}

struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 18
            for y in stride(from: CGFloat.zero, through: size.height, by: step) {
                for x in stride(from: CGFloat.zero, through: size.width, by: step) {
                    let hash = abs((Int(x) &* 73856093) ^ (Int(y) &* 19349663))
                    let alpha = 0.008 + Double(hash % 7) * 0.002
                    let rect = CGRect(x: x, y: y, width: 1.0, height: 1.0)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct FloatingCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color(red: 0.31, green: 0.22, blue: 0.12).opacity(0.10), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func floatingCard() -> some View {
        modifier(FloatingCardModifier())
    }
}
