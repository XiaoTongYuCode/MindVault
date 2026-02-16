import SwiftUI

struct TagAnalysisCard: View {
    @EnvironmentObject var languageManager: LanguageManager
    let tagAnalyses: [TagAnalysis]
    
    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("mood.tag.analysis.title".localized(using: languageManager))
                    .font(.system(size: 14))
                    .foregroundColor(MVTheme.muted)
                
                if tagAnalyses.isEmpty {
                    Text("mood.tag.analysis.empty".localized(using: languageManager))
                        .font(.system(size: 14))
                        .foregroundColor(MVTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 12) {
                        ForEach(tagAnalyses.prefix(5), id: \.tag) { analysis in
                            TagAnalysisRow(analysis: analysis)
                        }
                    }
                }
            }
        }
        .id(languageManager.currentLanguage.id)
    }
}

struct TagAnalysisRow: View {
    @EnvironmentObject var languageManager: LanguageManager
    let analysis: TagAnalysis
    
    // 计算情绪颜色
    private var sentimentColor: Color {
        guard let avgScore = analysis.averageScore else {
            return MVTheme.muted.opacity(0.1)
        }
        let display = SentimentDisplay.from(score: avgScore)
        return display.color.opacity(0.15)
    }
    
    // 根据 averageScore 计算渐变结束位置
    // averageScore 绝对值越大（情绪强度越大），情绪颜色延伸越远
    private var gradientEndLocation: Double {
        guard let avgScore = analysis.averageScore else {
            return 0.0
        }
        // 使用 averageScore 的绝对值，让情绪强度决定延伸距离
        // averageScore 范围是 [-1, 1]，绝对值范围是 [0, 1]
        let intensity = abs(avgScore)
        // 将强度映射到 0.3 到 0.7 之间，作为渐变结束位置
        // 强度为 0 时结束位置为 0.3，强度为 1 时结束位置为 0.7
        return 0.3 + (intensity * 0.4)
    }
    
    // 根据 averageScore 计算渐变过渡开始位置
    // 在结束位置前创建平滑过渡区域
    private var gradientTransitionStart: Double {
        guard let avgScore = analysis.averageScore else {
            return 0.0
        }
        // 基于 averageScore 的强度计算过渡区域
        let intensity = abs(avgScore)
        // 过渡区域宽度也随强度变化：强度越大，过渡区域越宽
        let transitionWidth = 0.1 + (intensity * 0.1) // 0.1 到 0.2 之间
        return max(0.0, gradientEndLocation - transitionWidth)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Tag emoji and name
            HStack(spacing: 6) {
                Text(analysis.tag.emoji)
                    .font(.system(size: 18))
                Text(analysis.tag.localizedName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MVTheme.foreground)
                // Entry count
                Text("(\(analysis.count))")
                    .font(.system(size: 12))
                    .foregroundColor(MVTheme.muted)
            }
            
            Spacer()
            
            // Average score with badge
            if let avgScore = analysis.averageScore {
                HStack(spacing: 8) {
                    CountUpView(
                        targetValue: avgScore,
                        format: "%.2f",
                        font: .system(size: 16, weight: .semibold),
                        foregroundColor: MVTheme.foreground,
                        duration: 1.0
                    )
                    
                    sentimentBadge(for: avgScore)
                }
            } else {
                Text("—")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(MVTheme.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                stops: [
                    // 左侧：纯情绪颜色
                    .init(color: sentimentColor, location: 0.0),
                    // 开始平滑过渡：情绪颜色逐渐变淡
                    .init(color: sentimentColor, location: gradientTransitionStart),
                    // 中间过渡：半透明情绪色到表面色
                    .init(color: sentimentColor.opacity(0.5), location: gradientEndLocation - 0.05),
                    // 继续过渡：更淡的情绪色
                    .init(color: sentimentColor.opacity(0.2), location: gradientEndLocation),
                    // 最终过渡到表面色
                    .init(color: MVTheme.surface.opacity(0.8), location: gradientEndLocation + 0.1),
                    // 右侧：纯表面色
                    .init(color: MVTheme.surface, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    @ViewBuilder
    private func sentimentBadge(for score: Double) -> some View {
        let sentimentDisplay = SentimentDisplay.from(score: score)
        HStack(spacing: 0) {
            AnimatedEmojiView(emoji: sentimentDisplay.emoji, imageName: sentimentDisplay.imageName, size: 24, animated: false)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            BreathingBackground<Capsule>(color: sentimentDisplay.color)
        )
        .foregroundColor(sentimentDisplay.color)
        .clipShape(Capsule())
    }
}

struct TagAnalysis {
    let tag: DiaryTag
    let averageScore: Double?
    let count: Int
    let distribution: MoodDistribution
    
    init(tag: DiaryTag, entries: [DiaryEntry]) {
        self.tag = tag
        self.count = entries.count
        
        let scores = entries.compactMap { $0.sentiment?.score }
        if scores.isEmpty {
            self.averageScore = nil
        } else {
            self.averageScore = scores.reduce(0, +) / Double(scores.count)
        }
        
        let labels = entries.compactMap { $0.sentiment?.label }
        self.distribution = MoodDistribution(labels: labels)
    }
}
