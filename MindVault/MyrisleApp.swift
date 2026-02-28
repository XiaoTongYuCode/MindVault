//
//  MyrisleApp.swift
//  Myrisle
//
//  Created by XTY on 2026/2/12.
//

import SwiftUI
import CoreData

@main
struct MyrisleApp: App {
    private let persistence = PersistenceController.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showSplash = true
    @State private var showOnboarding = false
    @State private var showContent = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(2)
                } else if showOnboarding {
                    OnboardingView(isComplete: $showOnboarding)
                        .environmentObject(languageManager)
                        .environmentObject(themeManager)
                        .transition(.opacity)
                        .zIndex(1)
                } else if showContent {
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
            .animation(.easeInOut(duration: 0.5), value: showOnboarding)
            .animation(.easeInOut(duration: 0.5), value: showContent)
            .onAppear {
                // 显示启动画面至少 0.5 秒，然后检查是否需要显示引导
                Task {
                    // 等待最小显示时间
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    
                    // 淡出启动画面
                    withAnimation {
                        showSplash = false
                    }
                    
                    // 检查是否已完成引导
                    let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
                    
                    // 短暂延迟后显示相应界面
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    
                    if hasCompletedOnboarding {
                        withAnimation {
                            showContent = true
                        }
                    } else {
                        withAnimation {
                            showOnboarding = true
                        }
                    }
                }
            }
            .onChange(of: showOnboarding) { oldValue, newValue in
                // 当引导完成时，显示主界面
                if oldValue && !newValue {
                    withAnimation {
                        showContent = true
                    }
                }
            }
        }
    }
}
