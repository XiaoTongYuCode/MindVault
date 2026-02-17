//
//  OnboardingView.swift
//  MindVault
//
//  Created on 2026/2/12.
//

import SwiftUI

/// 首次启动引导视图
struct OnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var languageManager: LanguageManager
    @State private var currentPage = 0
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
                        completeOnboarding()
                    } label: {
                        Text("onboarding.skip".localized(using: languageManager))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // 页面内容
                TabView(selection: $currentPage) {
                    // 屏1：价值主张
                    OnboardingPage(
                        title: "onboarding.page1.title".localized(using: languageManager),
                        description: "onboarding.page1.description".localized(using: languageManager),
                        icon: "lock.shield.fill"
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
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < totalPages - 1 ? "onboarding.continue".localized(using: languageManager) : "onboarding.start".localized(using: languageManager))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MVTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            isComplete = false  // false 表示引导已完成，不再显示
        }
    }
}

/// 单个引导页面
struct OnboardingPage: View {
    let title: String
    let description: String
    let icon: String
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 图标
            Image(systemName: icon)
                .font(.system(size: 100))
                .foregroundStyle(.white)
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
