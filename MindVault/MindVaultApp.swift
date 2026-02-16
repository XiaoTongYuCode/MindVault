//
//  MindVaultApp.swift
//  MindVault
//
//  Created by XTY on 2026/2/12.
//

import SwiftUI
import CoreData

@main
struct MindVaultApp: App {
    private let persistence = PersistenceController.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    ContentView(store: DiaryStore(context: persistence.container.viewContext))
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                        .environmentObject(languageManager)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.currentTheme == .classicDark ? .dark : .light)
                        .environment(\.locale, languageManager.currentLanguage.locale)
                        .transition(.opacity)
                        .zIndex(0)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onAppear {
                // 显示启动画面至少 0.5 秒，然后切换到主界面
                Task {
                    // 等待最小显示时间
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    
                    // 淡出启动画面
                    withAnimation {
                        showSplash = false
                    }
                }
            }
        }
    }
}
