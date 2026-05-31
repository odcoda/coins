import SwiftUI

struct ThemeStyle {
    var backgroundTop: Color
    var backgroundBottom: Color
    var accent: Color
    var secondaryAccent: Color
    var card: Color
    var cardStroke: Color
}

extension ThemeStyle {
    static let coins = ThemeStyle(
        backgroundTop: Color(red: 0.95, green: 0.90, blue: 0.72),
        backgroundBottom: Color(red: 0.44, green: 0.73, blue: 0.59),
        accent: Color(red: 0.89, green: 0.58, blue: 0.15),
        secondaryAccent: Color(red: 0.98, green: 0.79, blue: 0.26),
        card: Color.white.opacity(0.74),
        cardStroke: Color.white.opacity(0.55)
    )
}

func themeStyle(for theme: ThemeID) -> ThemeStyle {
    switch theme {
    case .coins:
        return .coins
    }
}

struct FloatingCoinsBackground: View {
    let style: ThemeStyle

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [style.backgroundTop, style.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(style.secondaryAccent.opacity(0.35))
                    .frame(width: size.width * 0.9)
                    .offset(x: size.width * 0.32, y: -size.height * 0.34)

                Circle()
                    .fill(style.accent.opacity(0.18))
                    .frame(width: size.width * 0.7)
                    .offset(x: -size.width * 0.36, y: size.height * 0.2)

                ForEach(0..<12, id: \.self) { index in
                    Text("¢")
                        .font(.system(size: CGFloat(18 + (index % 4) * 8), weight: .bold, design: .rounded))
                        .foregroundStyle(style.secondaryAccent.opacity(0.18))
                        .rotationEffect(.degrees(Double(index) * 17))
                        .offset(
                            x: CGFloat((index % 4) - 1) * size.width * 0.23,
                            y: CGFloat(index - 6) * size.height * 0.1
                        )
                }
            }
            .ignoresSafeArea()
        }
    }
}

