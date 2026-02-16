import SwiftUI

struct SentimentBadge: View {
    let sentiment: DiaryEntry.Sentiment?

    var body: some View {
        let display = SentimentDisplay.from(sentiment: sentiment)
        return HStack(spacing: 4) {
            AnimatedEmojiView(emoji: display.emoji, imageName: display.imageName, size: 20, animated: false)
        }
        .foregroundColor(display.color)
        .clipShape(Capsule())
    }
}
