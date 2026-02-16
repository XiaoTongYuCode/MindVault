import SwiftUI

struct EntryRow: View {
    let entry: DiaryEntry
    @EnvironmentObject var languageManager: LanguageManager
    
    private var sentimentColor: Color {
        guard let sentiment = entry.sentiment else {
            return MVTheme.muted.opacity(0.1)
        }
        let display = SentimentDisplay.from(sentiment: sentiment)
        return display.color.opacity(0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.createdAt.formattedForDiary())
                    .font(.system(size: 12))
                    .foregroundColor(MVTheme.muted)
                Spacer()
                HStack(spacing: 6) {
                    if let tag = entry.tag {
                        tagBadge(tag: tag)
                    }
                }
            }
            Text(entry.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MVTheme.foreground)
                .lineLimit(1)
            Text(sentimentSummaryText)
                .font(.system(size: 14, weight: .regular))
                .italic()
                .foregroundColor(MVTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                stops: [
                    .init(color: MVTheme.surface, location: 0.0),
                    .init(color: MVTheme.surface, location: 0.75),
                    .init(color: sentimentColor, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: MVTheme.shadowColor, radius: 10, x: 0, y: 6)
    }

    private func tagBadge(tag: DiaryTag) -> some View {
        HStack(spacing: 0) {
            Text(tag.localizedName)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(MVTheme.primary)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            Capsule()
                .fill(MVTheme.primary.opacity(0.12))
        )
    }

    private var sentimentSummaryText: String {
        if entry.isAnalyzing { return "entry.analyzing".localized(using: languageManager) }
        if let summary = entry.sentiment?.summary {
            // 如果 summary 是本地化键，则本地化；否则直接返回
            if summary.hasPrefix("entry.") || summary.hasPrefix("sentiment.") {
                return summary.localized(using: languageManager)
            }
            return summary
        }
        return "entry.analysis.failed".localized(using: languageManager)
    }
}
