import SwiftUI
import Foundation
import Combine

/// 支持的语言枚举
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
    
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// 语言管理器：负责管理应用的语言设置
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            updateBundle()
        }
    }
    
    private var bundle: Bundle = Bundle.main
    
    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // 如果没有保存的设置，使用系统语言
            let systemLanguage = Locale.preferredLanguages.first ?? "en"
            if systemLanguage.hasPrefix("zh") {
                self.currentLanguage = .chinese
            } else {
                self.currentLanguage = .english
            }
        }
        updateBundle()
    }
    
    private func updateBundle() {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // 如果找不到对应的语言包，使用主 bundle
            self.bundle = Bundle.main
            // 即使使用主 bundle，也要触发更新
            objectWillChange.send()
            return
        }
        self.bundle = bundle
        // 触发对象更新，让所有依赖的视图刷新
        objectWillChange.send()
    }
    
    /// 获取本地化字符串
    func localizedString(for key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}

/// 本地化字符串扩展
extension String {
    /// 获取本地化字符串
    /// 注意：为了确保 SwiftUI 能够追踪依赖，建议在视图中使用 @EnvironmentObject 的 languageManager
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }
    
    /// 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(for: self)
        return String(format: format, arguments: arguments)
    }
    
    /// 使用指定的 LanguageManager 获取本地化字符串（推荐在视图中使用）
    func localized(using manager: LanguageManager) -> String {
        return manager.localizedString(for: self)
    }
    
    /// 使用指定的 LanguageManager 获取带参数的本地化字符串（推荐在视图中使用）
    func localized(using manager: LanguageManager, with arguments: CVarArg...) -> String {
        let format = manager.localizedString(for: self)
        return String(format: format, arguments: arguments)
    }
}
