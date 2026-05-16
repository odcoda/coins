import SwiftUI

struct CoinBurstView: View {
    let trigger: Int
    let style: ThemeStyle
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Text("¢")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(style.secondaryAccent)
                    .offset(animate ? burstOffset(for: index) : .zero)
                    .scaleEffect(animate ? 0.8 : 0.1)
                    .opacity(animate ? 0 : 1)
                    .animation(.spring(response: 0.75, dampingFraction: 0.62).delay(Double(index) * 0.02), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger, initial: true) { _, _ in
            animate = false
            DispatchQueue.main.async {
                animate = true
            }
        }
    }

    private func burstOffset(for index: Int) -> CGSize {
        let angle = Double(index) / 10 * .pi * 2
        return CGSize(width: cos(angle) * 70, height: sin(angle) * 70)
    }
}

