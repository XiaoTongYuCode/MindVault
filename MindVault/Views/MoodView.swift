import SwiftUI
import Charts

struct MoodView: View {
    enum RangeOption: String, CaseIterable {
        case week
        case month
    }

    @ObservedObject var store: DiaryStore
    @State private var range: RangeOption = .week
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .fadeIn()
                rangePicker
                    .fadeIn()
                chartCard
                    .fadeIn()
                statsCards
                    .fadeIn()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(MVTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .id(languageManager.currentLanguage.id)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("mood.title".localized(using: languageManager))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(MVTheme.foreground)
            Text("mood.subtitle".localized(using: languageManager))
                .font(.system(size: 14))
                .foregroundColor(MVTheme.muted)
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 12) {
            ForEach(RangeOption.allCases, id: \.self) { option in
                rangePickerButton(for: option)
            }
        }
    }
    
    private func rangePickerButton(for option: RangeOption) -> some View {
        let isSelected = range == option
        let localizedText: String = {
            switch option {
            case .week:
                return "mood.range.week".localized(using: languageManager)
            case .month:
                return "mood.range.month".localized(using: languageManager)
            }
        }()
        return Button {
            withAnimation(AnimationHelpers.smoothSpring) {
                range = option
            }
        } label: {
            Text(localizedText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : MVTheme.foreground)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? AnyShapeStyle(MVTheme.gradient) : AnyShapeStyle(MVTheme.surface))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(MVTheme.border, lineWidth: isSelected ? 0 : 1)
                )
                .shadow(color: isSelected ? MVTheme.primary.opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableScaleStyle())
    }

    private var chartCard: some View {
        MoodChartCard(
            moodPoints: moodPoints,
            range: range == .week ? .week : .month
        )
        .environmentObject(languageManager)
    }

    private var statsCards: some View {
        VStack(spacing: 12) {
            StatCard(title: "mood.stats.average".localized(using: languageManager), value: averageText, badge: SentimentDisplay.from(score: averageScore))
                .transition(.scale.combined(with: .opacity))
            DistributionCard(distribution: distribution)
                .transition(.scale.combined(with: .opacity))
            TagAnalysisCard(tagAnalyses: tagAnalyses)
                .environmentObject(languageManager)
                .transition(.scale.combined(with: .opacity))
            StatCard(title: "mood.stats.total".localized(using: languageManager), value: "mood.stats.total.entries".localized(using: languageManager, with: filteredEntries.count), badge: nil)
                .transition(.scale.combined(with: .opacity))
        }
        .animation(AnimationHelpers.smoothSpring, value: range)
    }

    private var filteredEntries: [DiaryEntry] {
        let days = range == .week ? 7 : 30
        let cutoff = Calendar.current.date(byAdding: .day, value: -days + 1, to: Date()) ?? Date()
        return store.entries.filter { $0.createdAt >= cutoff }
    }

    private var moodPoints: [MoodPoint] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.createdAt)
        }
        var points = grouped.map { (date, entries) -> MoodPoint in
            let scores = entries.compactMap { $0.sentiment?.score }
            let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            return MoodPoint(date: date, score: avg, isPlaceholder: false)
        }
        points.sort { $0.date < $1.date }
        
        // 如果是周视图且数据不足7天，补齐前面的日期
        if range == .week {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            
            // 获取已有数据的日期集合
            let existingDates = Set(points.map { calendar.startOfDay(for: $0.date) })
            
            // 补齐缺失的日期
            var filledPoints: [MoodPoint] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                
                if existingDates.contains(dayStart) {
                    // 使用真实数据
                    if let realPoint = points.first(where: { calendar.startOfDay(for: $0.date) == dayStart }) {
                        filledPoints.append(realPoint)
                    }
                } else {
                    // 补齐数据，score为0
                    filledPoints.append(MoodPoint(date: dayStart, score: 0, isPlaceholder: true))
                }
            }
            return filledPoints
        }
        
        return points
    }

    private var averageScore: Double? {
        let scores = filteredEntries.compactMap { $0.sentiment?.score }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var averageText: String {
        guard let score = averageScore else { return "—" }
        return String(format: "%.2f", score)
    }

    private var distribution: MoodDistribution {
        let sentiments = filteredEntries.compactMap { $0.sentiment?.label }
        return MoodDistribution(labels: sentiments)
    }
    
    private var tagAnalyses: [TagAnalysis] {
        // 按tag分组
        let grouped = Dictionary(grouping: filteredEntries) { entry -> DiaryTag? in
            entry.tag
        }
        
        // 过滤掉没有tag的条目，并为每个tag创建分析
        let analyses = grouped.compactMap { (tag, entries) -> TagAnalysis? in
            guard let tag = tag else { return nil }
            return TagAnalysis(tag: tag, entries: entries)
        }
        
        // 按平均分数降序排序，如果分数相同则按数量降序
        return analyses.sorted { analysis1, analysis2 in
            let score1 = analysis1.averageScore ?? -999
            let score2 = analysis2.averageScore ?? -999
            if abs(score1 - score2) > 0.01 {
                return score1 > score2
            }
            return analysis1.count > analysis2.count
        }
    }
}
