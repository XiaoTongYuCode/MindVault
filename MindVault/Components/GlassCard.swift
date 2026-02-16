import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let cornerRadius: CGFloat = 22
        let isDarkTheme = ThemeManager.shared.currentTheme == .classicDark
        
        // 根据主题动态选择高光颜色
        let highlightColor: Color = isDarkTheme ? MVTheme.surface : .white

        return content
            .padding(16)
            .background(
                ZStack {
                    // 更薄的磨砂材质，让背景更多地透出来
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)

                    // 顶部通透、底部偏白的玻璃高光，让卡片呈现"上透下白"的磨砂感
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    highlightColor.opacity(0.25),   // 顶部透明
                                    highlightColor.opacity(0.45),
                                    highlightColor.opacity(0.85)   // 底部更亮
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.screen)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                // 更锐利的玻璃边缘描边
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                highlightColor.opacity(0.8),
                                highlightColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.screen)
            )
            // 轻微投影，抬起卡片
            .shadow(color: MVTheme.strongShadowColor, radius: 18, x: 0, y: 12)
    }
}
