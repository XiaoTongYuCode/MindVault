import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let badge: SentimentDisplay?

    var body: some View {
        SoftCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(MVTheme.muted)
                    Text(value)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(MVTheme.foreground)
                }
                Spacer()
                if let badge = badge {
                    HStack(spacing: 0) {
                        AnimatedEmojiView(emoji: badge.emoji, imageName: badge.imageName, size: 34)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(badge.color.opacity(0.15))
                    .foregroundColor(badge.color)
                    .clipShape(Capsule())
                }
            }
        }
    }
}
