import SwiftUI

/// 主题颜色访问器：提供动态主题支持
struct MVTheme {
    // 使用 ThemeManager 获取当前主题颜色
    private static var themeManager: ThemeManager {
        ThemeManager.shared
    }
    
    // 动态主题颜色属性
    static var primary: Color {
        themeManager.colors.primary
    }
    
    static var primaryLight: Color {
        themeManager.colors.primaryLight
    }
    
    static var background: Color {
        themeManager.colors.background
    }
    
    static var surface: Color {
        themeManager.colors.surface
    }
    
    static var foreground: Color {
        themeManager.colors.foreground
    }
    
    static var muted: Color {
        themeManager.colors.muted
    }
    
    static var border: Color {
        themeManager.colors.border
    }
    
    static var success: Color {
        themeManager.colors.success
    }
    
    static var warning: Color {
        themeManager.colors.warning
    }
    
    static var error: Color {
        themeManager.colors.error
    }
    
    static var gradient: LinearGradient {
        themeManager.colors.gradient
    }
    
    /// 根据主题返回合适的阴影颜色
    /// 浅色主题使用黑色阴影，深色主题使用主色调的发光效果
    static var shadowColor: Color {
        if themeManager.currentTheme == .classicDark {
            // 深色主题：使用主色调的发光效果
            return primary.opacity(0.15)
        } else {
            // 浅色主题：使用黑色阴影
            return Color.black.opacity(0.06)
        }
    }
    
    /// 根据主题返回合适的强阴影颜色（用于卡片等）
    static var strongShadowColor: Color {
        if themeManager.currentTheme == .classicDark {
            // 深色主题：使用主色调的发光效果
            return primary.opacity(0.2)
        } else {
            // 浅色主题：使用黑色阴影
            return Color.black.opacity(0.08)
        }
    }
}
