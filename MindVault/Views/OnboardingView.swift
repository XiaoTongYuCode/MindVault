//
//  OnboardingView.swift
//  Myrisle
//
//  Created on 2026/2/12.
//

import SwiftUI

/// 首次启动引导视图
struct OnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var languageManager: LanguageManager
    @State private var currentPage = 0
    @State private var isLoading = false
    @Binding var isComplete: Bool
    
    private let totalPages = 3
    
    var body: some View {
        ZStack {
            // 背景使用主题渐变
            MVTheme.gradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部跳过按钮
                HStack {
                    Spacer()
                    Button {
                        isLoading = true
                        Task {
                            await completeOnboarding()
                        }
                    } label: {
                        Text("onboarding.skip".localized(using: languageManager))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .disabled(isLoading)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // 页面内容
                TabView(selection: $currentPage) {
                    // 屏1：价值主张
                    OnboardingPage(
                        title: "onboarding.page1.title".localized(using: languageManager),
                        description: "onboarding.page1.description".localized(using: languageManager),
                        icon: "lock.shield.fill",
                        useLogo: true
                    )
                    .tag(0)
                    
                    // 屏2：技术信任
                    OnboardingPage(
                        title: "onboarding.page2.title".localized(using: languageManager),
                        description: "onboarding.page2.description".localized(using: languageManager),
                        icon: "cpu.fill"
                    )
                    .tag(1)
                    
                    // 屏3：行动号召
                    OnboardingPage(
                        title: "onboarding.page3.title".localized(using: languageManager),
                        description: "onboarding.page3.description".localized(using: languageManager),
                        icon: "heart.text.square.fill"
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // 页面指示器
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.4))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                // 底部按钮
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentPage -= 1
                            }
                        } label: {
                            Text("onboarding.back".localized(using: languageManager))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                    } else {
                        // 占位，保持按钮对齐
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button {
                        if currentPage < totalPages - 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentPage += 1
                            }
                        } else {
                            isLoading = true
                            Task {
                                await completeOnboarding()
                            }
                        }
                    } label: {
                        HStack {
                            if isLoading && currentPage >= totalPages - 1 {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MVTheme.primary))
                                    .scaleEffect(0.8)
                            } else {
                                Text(currentPage < totalPages - 1 ? "onboarding.continue".localized(using: languageManager) : "onboarding.start".localized(using: languageManager))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(MVTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                    }
                    .disabled(isLoading && currentPage >= totalPages - 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeOnboarding() async {
        // 给一点时间显示加载状态，避免闪烁
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
                isComplete = false  // false 表示引导已完成，不再显示
            }
        }
    }
}

/// 应用 Logo 加载辅助方法，供多个视图复用
func loadAppLogo() -> UIImage? {
    // 尝试多种路径和扩展名组合来加载 logo 图片
    var logoURL: URL?

    // 方式: 直接查找（不带子目录）
    if let url = Bundle.main.url(forResource: "logo", withExtension: "PNG") {
        logoURL = url
    } else if let url = Bundle.main.url(forResource: "logo", withExtension: "png") {
        logoURL = url
    }
    
    if let logoURL = logoURL {
        return UIImage(contentsOfFile: logoURL.path)
    }
    return nil
}

/// 单个引导页面
struct OnboardingPage: View {
    let title: String
    let description: String
    let icon: String
    let useLogo: Bool

    init(title: String, description: String, icon: String, useLogo: Bool = false) {
        self.title = title
        self.description = description
        self.icon = icon
        self.useLogo = useLogo
    }
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var logoImage: UIImage?
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 图标（仅在需要时使用应用 Logo 图片）
            Group {
                if useLogo, let logoImage = logoImage {
                    Image(uiImage: logoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                } else {
                    // 回退到 SF Symbol（如果图片加载失败）
                    Image(systemName: icon)
                        .font(.system(size: 100))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            
            // 标题和描述
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(opacity)
                    .offset(y: opacity > 0 ? 0 : 20)
                
                Text(description)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .opacity(opacity)
                    .offset(y: opacity > 0 ? 0 : 20)
            }
            
            Spacer()
        }
        .onAppear {
            if useLogo {
                logoImage = loadAppLogo()
            } else {
                logoImage = nil
            }
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
        .environmentObject(LanguageManager.shared)
        .environmentObject(ThemeManager.shared)
}
