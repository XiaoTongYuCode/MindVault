import SwiftUI
import Foundation
import Combine

/// 主题类型枚举
enum AppTheme: String, CaseIterable, Identifiable {
    case warmPinkOrange = "warm_pink_orange"    // 温暖粉橙（默认）
    case freshBlueGreen = "fresh_blue_green"    // 清新蓝绿
    case elegantPurplePink = "elegant_purple_pink" // 优雅紫粉
    case classicDark = "classic_dark"           // 经典深色
    case naturalGreen = "natural_green"         // 自然绿色
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .warmPinkOrange:
            return "温暖粉橙"
        case .freshBlueGreen:
            return "清新蓝绿"
        case .elegantPurplePink:
            return "优雅紫粉"
        case .classicDark:
            return "经典深色"
        case .naturalGreen:
            return "自然绿色"
        }
    }
    
    var displayNameEN: String {
        switch self {
        case .warmPinkOrange:
            return "Warm Pink Orange"
        case .freshBlueGreen:
            return "Fresh Blue Green"
        case .elegantPurplePink:
            return "Elegant Purple Pink"
        case .classicDark:
            return "Classic Dark"
        case .naturalGreen:
            return "Natural Green"
        }
    }
    
    /// 获取本地化显示名称
    func localizedName(using languageManager: LanguageManager) -> String {
        if languageManager.currentLanguage == .chinese {
            return displayName
        } else {
            return displayNameEN
        }
    }
    
    /// 主题颜色配置
    var colors: ThemeColors {
        switch self {
        case .warmPinkOrange:
            return ThemeColors(
                primary: Color(hex: "#FF6B9D"),
                primaryLight: Color(hex: "#FFB88C"),
                background: Color(hex: "#FFF8F5"),
                surface: Color.white,
                foreground: Color(hex: "#2D2D2D"),
                muted: Color(hex: "#8B8B8B"),
                border: Color(hex: "#F0E6E0"),
                success: Color(hex: "#10B981"),
                warning: Color(hex: "#F59E0B"),
                error: Color(hex: "#EF4444")
            )
        case .freshBlueGreen:
            return ThemeColors(
                primary: Color(hex: "#4A90E2"),
                primaryLight: Color(hex: "#7BC8A4"),
                background: Color(hex: "#F0F7FF"),
                surface: Color.white,
                foreground: Color(hex: "#1A1A2E"),
                muted: Color(hex: "#6B7280"),
                border: Color(hex: "#D1E7DD"),
                success: Color(hex: "#10B981"),
                warning: Color(hex: "#F59E0B"),
                error: Color(hex: "#EF4444")
            )
        case .elegantPurplePink:
            return ThemeColors(
                primary: Color(hex: "#9B59B6"),
                primaryLight: Color(hex: "#E91E63"),
                background: Color(hex: "#FDF2F8"),
                surface: Color.white,
                foreground: Color(hex: "#2D1B3D"),
                muted: Color(hex: "#8B7A9B"),
                border: Color(hex: "#E9D5E3"),
                success: Color(hex: "#10B981"),
                warning: Color(hex: "#F59E0B"),
                error: Color(hex: "#EF4444")
            )
        case .classicDark:
            return ThemeColors(
                primary: Color(hex: "#6366F1"),
                primaryLight: Color(hex: "#818CF8"),
                background: Color(hex: "#1E1E2E"),
                surface: Color(hex: "#2D2D3D"),
                foreground: Color(hex: "#E4E4E7"),
                muted: Color(hex: "#A1A1AA"),
                border: Color(hex: "#3F3F46"),
                success: Color(hex: "#10B981"),
                warning: Color(hex: "#F59E0B"),
                error: Color(hex: "#EF4444")
            )
        case .naturalGreen:
            return ThemeColors(
                primary: Color(hex: "#22C55E"),
                primaryLight: Color(hex: "#4ADE80"),
                background: Color(hex: "#F0FDF4"),
                surface: Color.white,
                foreground: Color(hex: "#1F2937"),
                muted: Color(hex: "#6B7280"),
                border: Color(hex: "#D1FAE5"),
                success: Color(hex: "#10B981"),
                warning: Color(hex: "#F59E0B"),
                error: Color(hex: "#EF4444")
            )
        }
    }
}

/// 主题颜色结构
struct ThemeColors {
    let primary: Color
    let primaryLight: Color
    let background: Color
    let surface: Color
    let foreground: Color
    let muted: Color
    let border: Color
    let success: Color
    let warning: Color
    let error: Color
    
    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// 主题管理器：负责管理应用的主题设置
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
            objectWillChange.send()
        }
    }
    
    private init() {
        // 从 UserDefaults 读取保存的主题设置
        if let savedTheme = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            // 如果没有保存的设置，使用默认主题
            self.currentTheme = .warmPinkOrange
        }
    }
    
    /// 切换主题
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
    
    /// 获取当前主题的颜色
    var colors: ThemeColors {
        currentTheme.colors
    }
}
