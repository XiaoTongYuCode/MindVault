import SwiftUI

struct HomeView: View {
    @ObservedObject var store: DiaryStore
    @Binding var showCompose: Bool
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            HeaderBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                        .fadeIn()
                    overviewCard
                    writeButton
                        .fadeIn()
                    recentEntries
                        .fadeIn()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(MVTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarHidden(true)
        .id(languageManager.currentLanguage.id)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(languageManager)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white)
            Text("home.subtitle".localized(using: languageManager))
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white.opacity(0.70))
        }
        .padding(.top, 8)
    }

    private var overviewCard: some View {
        let count = store.entries.filter { Calendar.current.isDateInToday($0.createdAt) }.count
        let avgScore = store.entries.isEmpty ? nil : store.entries.map { $0.sentiment?.score ?? 0 }.reduce(0, +) / Double(store.entries.count)
        let sentiment = SentimentDisplay.from(score: avgScore)
        return GlassCard {
            HStack(alignment: .center, spacing: 5) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("home.overview.title".localized(using: languageManager))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(MVTheme.foreground)
                    Text("home.overview.entries".localized(using: languageManager, with: count))
                        .font(.system(size: 16))
                        .foregroundColor(MVTheme.muted)
                }
                Spacer()
                HStack(alignment: .center, spacing: 8) {
                    CountUpView.signed(
                        targetValue: sentiment.score ?? 0,
                        decimals: 2,
                        font: .system(size: 38, weight: .bold),
                        foregroundColor: MVTheme.primary,
                        duration: 1.5
                    )
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    AnimatedEmojiView(emoji: sentiment.emoji, imageName: sentiment.imageName, size: 38)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.top, 6)
    }

    private var aiGreetingCard: some View {
        Group {
            if !store.aiGreeting.isEmpty {
                GlassCard {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MVTheme.primary)
                            .padding(.top, 2)
                        
                        Text(processedAiGreeting)
                            .font(.system(size: 15))
                            .foregroundColor(MVTheme.foreground.opacity(0.8))
                            .lineLimit(3)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var writeButton: some View {
        Button {
            showCompose = true
        } label: {
            HStack {
                Spacer()
                Text("home.write.button".localized(using: languageManager))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(MVTheme.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: MVTheme.primary.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(PressableScaleStyle())
    }

    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("home.recent.title".localized(using: languageManager))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(MVTheme.foreground)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(MVTheme.foreground)
                }
                .buttonStyle(PressableScaleStyle())
            }
            
            // AI问候卡片
            aiGreetingCard

            if store.entries.isEmpty {
                GeometryReader { geometry in
                    EmptyStateView(
                        title: "home.empty.title".localized(using: languageManager),
                        message: "home.empty.message".localized(using: languageManager),
                        actionTitle: "home.empty.action".localized(using: languageManager),
                        action: { showCompose = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .frame(height: geometry.size.height)
                }
                .frame(minHeight: 250)
            } else {
                ForEach(Array(store.entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    NavigationLink(value: entry) {
                        EntryCard(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .listItemAnimation(index: index)
                }
            }
        }
        .navigationDestination(for: DiaryEntry.self) { entry in
            EntryDetailView(store: store, entry: entry)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "home.greeting.morning".localized(using: languageManager)
        case 12..<18: return "home.greeting.afternoon".localized(using: languageManager)
        case 18..<23: return "home.greeting.evening".localized(using: languageManager)
        default: return "home.greeting.night".localized(using: languageManager)
        }
    }
    
    /// 处理AI问候语，限制最多两句话（以句号"。"为分隔）
    private var processedAiGreeting: String {
        let text = store.aiGreeting
        // 找到所有句号的位置
        var periods: [String.Index] = []
        var searchIndex = text.startIndex
        
        while searchIndex < text.endIndex {
            if let range = text.range(of: "。", range: searchIndex..<text.endIndex) {
                periods.append(range.upperBound)
                searchIndex = range.upperBound
            } else {
                break
            }
        }
        
        // 如果句号数量 <= 2，直接返回原文本
        if periods.count <= 2 {
            return text
        }
        
        // 如果句号数量 > 2，只保留第二个句号及其之前的内容
        let secondPeriodIndex = periods[1]
        return String(text[..<secondPeriodIndex])
    }
}
