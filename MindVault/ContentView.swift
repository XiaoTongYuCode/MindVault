import SwiftUI
import CoreData

/// 应用根视图：负责创建 `DiaryStore` 并组织 Tab 布局
struct ContentView: View {
    @StateObject private var store: DiaryStore
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showCompose = false
    @State private var selectedTab = 0
    @State private var homeNavigationPath = NavigationPath()
    @State private var entriesNavigationPath = NavigationPath()
    @State private var moodNavigationPath = NavigationPath()
    @State private var chatNavigationPath = NavigationPath()

    init(store: DiaryStore? = nil) {
        if let store {
            _store = StateObject(wrappedValue: store)
        } else {
            let context = PersistenceController.shared.container.viewContext
            _store = StateObject(wrappedValue: DiaryStore(context: context))
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeNavigationPath) {
                HomeView(store: store, showCompose: $showCompose, navigationPath: $homeNavigationPath)
            }
            .tabItem {
                Label("tab.home".localized(using: languageManager), systemImage: "house")
            }
            .tag(0)

            NavigationStack(path: $entriesNavigationPath) {
                EntriesView(store: store, showCompose: $showCompose, navigationPath: $entriesNavigationPath)
            }
            .tabItem {
                Label("tab.entries".localized(using: languageManager), systemImage: "book.closed")
            }
            .tag(1)

            NavigationStack(path: $moodNavigationPath) {
                MoodView(store: store)
            }
            .tabItem {
                Label("tab.mood".localized(using: languageManager), systemImage: "waveform.path.ecg")
            }
            .tag(2)

            NavigationStack(path: $chatNavigationPath) {
                ChatView()
            }
            .tabItem {
                Label("tab.chat".localized(using: languageManager), systemImage: "heart.text.square")
            }
            .tag(3)
        }
        .animation(AnimationHelpers.smoothEaseInOut, value: selectedTab)
        .onChange(of: selectedTab) { oldValue, newValue in
            // 当切换 Tab 时，重置对应 Tab 的导航路径
            switch newValue {
            case 0:
                if !homeNavigationPath.isEmpty {
                    homeNavigationPath.removeLast(homeNavigationPath.count)
                }
            case 1:
                if !entriesNavigationPath.isEmpty {
                    entriesNavigationPath.removeLast(entriesNavigationPath.count)
                }
            case 2:
                if !moodNavigationPath.isEmpty {
                    moodNavigationPath.removeLast(moodNavigationPath.count)
                }
            case 3:
                if !chatNavigationPath.isEmpty {
                    chatNavigationPath.removeLast(chatNavigationPath.count)
                }
            default:
                break
            }
        }
        .tint(MVTheme.primary)
        .id(languageManager.currentLanguage.id)
        .id(themeManager.currentTheme.id)
        .sheet(isPresented: $showCompose) {
            ComposeView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // App 启动后，在真正的后台任务中预热情感分析模型（以及底层 Llama 模型），避免阻塞主线程
        .task {
            Task.detached(priority: .background) {
                await store.warmUpSentimentAnalyzer()
            }
        }
    }
}
