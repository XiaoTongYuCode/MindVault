//
//  SplashView.swift
//  Myrisle
//
//  Created on 2026/2/12.
//

import SwiftUI

/// 启动画面视图
struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var rotation: Double = 0
    @State private var logoImage: UIImage?
    
    var body: some View {
        ZStack {
            // 背景使用主题渐变
            MVTheme.gradient
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 应用图标（优先使用自定义 Logo 图片）
                Group {
                    if let logoImage = logoImage {
                        Image(uiImage: logoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    } else {
                        // 回退到 SF Symbol（如果图片加载失败）
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .rotationEffect(.degrees(rotation))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                
                // 应用名称（可选）
                Text("Myrisle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
                    .offset(y: opacity > 0 ? 0 : 20)
            }
        }
        .onAppear {
            // 加载 Logo 图片
            logoImage = loadAppLogo()
            
            // 启动动画序列
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // 轻微的旋转动画
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                rotation = 5
            }
        }
    }
}

#Preview {
    SplashView()
}
