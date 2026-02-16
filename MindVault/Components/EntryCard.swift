import SwiftUI

struct EntryCard: View {
    let entry: DiaryEntry
    
    private var sentimentColor: Color {
        guard let sentiment = entry.sentiment else {
            return MVTheme.muted.opacity(0.1)
        }
        let display = SentimentDisplay.from(sentiment: sentiment)
        return display.color.opacity(0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title 放在最上面，给右侧 emoji 留出空间
            Text(entry.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(MVTheme.foreground)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 48) // 为右侧 emoji (28 + 10*2 padding) 留出空间
            
            // 日期在 title 下方
            HStack(spacing: 8) {
                if let tag = entry.tag {
                    tagBadge(tag: tag)
                } else {
                    tagBadge(tag: .other)
                }

                Text(entry.createdAt.formattedForDiary())
                    .font(.system(size: 12))
                    .foregroundColor(MVTheme.muted)
                
                Spacer()
            }
            
            // 内容（如果title是content的开头内容则不展示）
            if !entry.content.hasPrefix(entry.title) {
                Text(entry.content)
                    .font(.system(size: 14))
                    .foregroundColor(MVTheme.muted)
                    .lineLimit(2)
            }
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
        .overlay(alignment: .topTrailing) {
            // 显示情绪emoji或分析进度圈
            if let sentiment = entry.sentiment {
                let display = SentimentDisplay.from(sentiment: sentiment)
                AnimatedEmojiView(emoji: sentiment.emoji, imageName: display.imageName, size: 28, animated: false)
                    .padding(10)
            } else if entry.isAnalyzing {
                // 分析过程中显示蓝色线条加载进度圈
                LoadingProgressCircle()
                    .frame(width: 16, height: 16)
                    .padding(16)
            }
        }
    }
    
    private func tagBadge(tag: DiaryTag) -> some View {
        HStack(spacing: 3) {
            Text(tag.localizedName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(MVTheme.primary)
    }
}

/// 蓝色线条加载进度圈
struct LoadingProgressCircle: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 背景圆圈（浅色）
            Circle()
                .stroke(MVTheme.primary.opacity(0.2), lineWidth: 3)
            
            // 进度线条
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    MVTheme.primary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 1.0)
                    .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
    }
}
