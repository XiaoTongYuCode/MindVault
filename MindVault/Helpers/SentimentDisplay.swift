import SwiftUI

struct SentimentDisplay {
    let label: String  // 本地化键（如 "mood.very_positive"）
    let emoji: String
    let imageName: String?  // 图片资源名称（用于 WebP/GIF 动图）
    let color: Color
    let score: Double?
    let summary: String  // 可能是本地化键或普通文本

    var scoreText: String {
        guard let score else { return "—" }
        return String(format: "%.2f", score)
    }
    
    /// 获取本地化后的标签文本
    var localizedLabel: String {
        label.localized
    }
    
    /// 获取本地化后的摘要文本（如果是本地化键则本地化，否则直接返回）
    var localizedSummary: String {
        if summary.hasPrefix("sentiment.") || summary.hasPrefix("mood.") {
            return summary.localized
        }
        return summary
    }

    static func from(sentiment: DiaryEntry.Sentiment?) -> SentimentDisplay {
        guard let sentiment else {
            return SentimentDisplay(
                label: "sentiment.not_analyzed",
                emoji: "⏳",
                imageName: nil,
                color: MVTheme.muted,
                score: nil,
                summary: "sentiment.analyzing"
            )
        }
        // label 可能是本地化键或旧的中文标签，显示时使用本地化
        let displayLabel = sentiment.label.hasPrefix("mood.") ? sentiment.label : normalizeLabel(sentiment.label)
        return SentimentDisplay(
            label: displayLabel,
            emoji: sentiment.emoji,
            imageName: imageNameForSentiment(displayLabel),
            color: color(for: displayLabel, score: sentiment.score),
            score: sentiment.score,
            summary: sentiment.summary
        )
    }

    static func from(score: Double?) -> SentimentDisplay {
        guard let score else {
            return SentimentDisplay(
                label: "sentiment.no_data",
                emoji: "📝",
                imageName: nil,
                color: MVTheme.muted,
                score: nil,
                summary: ""
            )
        }
        // 5个情绪等级：-2, -1, 0, 1, 2
        // 使用本地化键作为 label
        if score > 0.6 {
            return SentimentDisplay(
                label: "mood.very_positive",
                emoji: "😄",
                imageName: "emoji_very_positive",
                color: MVTheme.success,
                score: score,
                summary: ""
            )
        } else if score > 0.2 {
            return SentimentDisplay(
                label: "mood.positive",
                emoji: "😊",
                imageName: "emoji_positive",
                color: MVTheme.success.opacity(0.8),
                score: score,
                summary: ""
            )
        } else if score < -0.6 {
            return SentimentDisplay(
                label: "mood.very_negative",
                emoji: "😢",
                imageName: "emoji_very_negative",
                color: MVTheme.error,
                score: score,
                summary: ""
            )
        } else if score < -0.2 {
            return SentimentDisplay(
                label: "mood.negative",
                emoji: "😔",
                imageName: "emoji_negative",
                color: MVTheme.error.opacity(0.8),
                score: score,
                summary: ""
            )
        } else {
            return SentimentDisplay(
                label: "mood.neutral",
                emoji: "😐",
                imageName: "emoji_neutral",
                color: MVTheme.warning,
                score: score,
                summary: ""
            )
        }
    }
    
    /// 根据情感标签返回对应的图片资源名称
    /// 图片命名规则：emoji_very_positive, emoji_positive, emoji_neutral, emoji_negative, emoji_very_negative
    /// 支持本地化键和旧的中文标签（向后兼容）
    private static func imageNameForSentiment(_ label: String) -> String? {
        let normalizedLabel = normalizeLabel(label)
        switch normalizedLabel {
        case "mood.very_positive": return "emoji_very_positive"
        case "mood.positive": return "emoji_positive"
        case "mood.neutral": return "emoji_neutral"
        case "mood.negative": return "emoji_negative"
        case "mood.very_negative": return "emoji_very_negative"
        default: return nil
        }
    }
    
    /// 将旧的中文标签转换为本地化键，或直接返回本地化键
    private static func normalizeLabel(_ label: String) -> String {
        // 如果已经是本地化键，直接返回
        if label.hasPrefix("mood.") {
            return label
        }
        // 将旧的中文标签转换为本地化键
        switch label {
        case "兴奋": return "mood.very_positive"
        case "积极": return "mood.positive"
        case "中性": return "mood.neutral"
        case "消极": return "mood.negative"
        case "沮丧": return "mood.very_negative"
        default: return label
        }
    }

    private static func color(for label: String, score: Double) -> Color {
        let normalizedLabel = normalizeLabel(label)
        switch normalizedLabel {
        case "mood.very_positive": return MVTheme.success
        case "mood.positive": return MVTheme.success.opacity(0.8)
        case "mood.neutral": return MVTheme.warning
        case "mood.negative": return MVTheme.error.opacity(0.8)
        case "mood.very_negative": return MVTheme.error
        default:
            // 回退逻辑：根据 score 判断
            if score > 0.6 { return MVTheme.success }
            if score > 0.2 { return MVTheme.success.opacity(0.8) }
            if score < -0.6 { return MVTheme.error }
            if score < -0.2 { return MVTheme.error.opacity(0.8) }
            return MVTheme.warning
        }
    }
}

struct MoodPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
    let isPlaceholder: Bool  // 标记是否为补齐的数据点
    
    init(date: Date, score: Double, isPlaceholder: Bool = false) {
        self.date = date
        self.score = score
        self.isPlaceholder = isPlaceholder
    }
}

struct MoodDistribution {
    let veryPositive: Int  // 兴奋 (2)
    let positive: Int       // 积极 (1)
    let neutral: Int       // 中性 (0)
    let negative: Int      // 消极 (-1)
    let veryNegative: Int  // 沮丧 (-2)

    init(labels: [String]) {
        // 支持本地化键和旧的中文标签（向后兼容）
        veryPositive = labels.filter { MoodDistribution.normalizeLabel($0) == "mood.very_positive" }.count
        positive = labels.filter { MoodDistribution.normalizeLabel($0) == "mood.positive" }.count
        neutral = labels.filter { MoodDistribution.normalizeLabel($0) == "mood.neutral" }.count
        negative = labels.filter { MoodDistribution.normalizeLabel($0) == "mood.negative" }.count
        veryNegative = labels.filter { MoodDistribution.normalizeLabel($0) == "mood.very_negative" }.count
    }
    
    /// 将旧的中文标签转换为本地化键，或直接返回本地化键
    private static func normalizeLabel(_ label: String) -> String {
        // 如果已经是本地化键，直接返回
        if label.hasPrefix("mood.") {
            return label
        }
        // 将旧的中文标签转换为本地化键
        switch label {
        case "兴奋": return "mood.very_positive"
        case "积极": return "mood.positive"
        case "中性": return "mood.neutral"
        case "消极": return "mood.negative"
        case "沮丧": return "mood.very_negative"
        default: return label
        }
    }

    var total: Int { max(veryPositive + positive + neutral + negative + veryNegative, 1) }
    var veryPositiveRatio: Double { Double(veryPositive) / Double(total) }
    var positiveRatio: Double { Double(positive) / Double(total) }
    var neutralRatio: Double { Double(neutral) / Double(total) }
    var negativeRatio: Double { Double(negative) / Double(total) }
    var veryNegativeRatio: Double { Double(veryNegative) / Double(total) }
    
    // 兼容旧版本的属性（用于向后兼容）
    var positiveCount: Int { veryPositive + positive }
    var negativeCount: Int { negative + veryNegative }
}
