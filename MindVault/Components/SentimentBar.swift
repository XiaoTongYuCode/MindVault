import SwiftUI

struct SentimentBar: View {
    let score: Double?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(MVTheme.border.opacity(0.5))
                    .frame(height: 8)
                if let score = score {
                    let position = (score + 1) / 2
                    Circle()
                        .fill(MVTheme.gradient)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, min(width - 14, width * position - 7)))
                }
            }
        }
        .frame(height: 14)
    }
}
