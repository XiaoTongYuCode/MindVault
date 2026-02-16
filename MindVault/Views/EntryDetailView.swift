import SwiftUI

struct EntryDetailView: View {
    @ObservedObject var store: DiaryStore
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14))
                        .foregroundColor(MVTheme.muted)
                    Spacer()
                    if let tag = entry.tag {
                        tagBadge(tag: tag)
                    }
                }
                .fadeIn()
                Text(entry.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(MVTheme.foreground)
                    .fadeIn()
                Text(entry.content)
                    .font(.system(size: 17))
                    .foregroundColor(MVTheme.foreground)
                    .lineSpacing(8)
                    .fadeIn()

                sentimentCard
                    .fadeIn()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(MVTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("entry.detail.title".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(MVTheme.foreground)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("entry.detail.delete".localized) { showDelete = true }
                    .foregroundColor(MVTheme.error)
            }
        }
        .alert("entry.detail.delete.alert.title".localized, isPresented: $showDelete) {
            Button("entry.detail.delete.alert.cancel".localized, role: .cancel) {}
            Button("entry.detail.delete.alert.confirm".localized, role: .destructive) {
                store.deleteEntry(entry)
                dismiss()
            }
        } message: {
            Text("entry.detail.delete.alert.message".localized)
        }
    }

    private func tagBadge(tag: DiaryTag) -> some View {
        HStack(spacing: 4) {
            Text(tag.emoji)
                .font(.system(size: 12))
            Text(tag.localizedName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(MVTheme.primary)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(MVTheme.primary.opacity(0.12))
        )
    }

    private var sentimentCard: some View {
        let display = SentimentDisplay.from(sentiment: entry.sentiment)
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    AnimatedEmojiView(emoji: display.emoji, imageName: display.imageName, size: 42)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(display.localizedLabel)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(MVTheme.foreground)
                            Text(display.scoreText)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(MVTheme.primary)
                        }
                        Text(display.localizedSummary)
                            .font(.system(size: 13))
                            .foregroundColor(MVTheme.muted)
                    }
                }
                SentimentBar(score: display.score)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(MVTheme.gradient, lineWidth: 1)
        )
        .padding(.top, 16)
    }
}
