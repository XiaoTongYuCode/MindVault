import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsList
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(MVTheme.background.ignoresSafeArea())
            .navigationTitle("settings.title".localized(using: languageManager))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
            // 确保语言和主题切换时视图会重新计算
            .id(languageManager.currentLanguage.id)
            .id(themeManager.currentTheme.id)
        }
    }
    
    private var settingsList: some View {
        VStack(spacing: 0) {
            // 语言设置部分
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.language.title".localized(using: languageManager))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(MVTheme.foreground)
                    Text("settings.language.description".localized(using: languageManager))
                        .font(.system(size: 14))
                        .foregroundColor(MVTheme.muted)
                }
                
                Spacer()
                
                Menu {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            withAnimation {
                                languageManager.setLanguage(language)
                            }
                        } label: {
                            HStack {
                                Text(language.displayName)
                                if languageManager.currentLanguage == language {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(languageManager.currentLanguage.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MVTheme.foreground)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(MVTheme.muted)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MVTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MVTheme.border, lineWidth: 1)
                    )
                }
            }
            .padding(.bottom, 16)
            
            // 分割线
            Divider()
                .background(MVTheme.border)
                .padding(.vertical, 16)
            
            // 主题设置部分
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.theme.title".localized(using: languageManager))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(MVTheme.foreground)
                    Text("settings.theme.description".localized(using: languageManager))
                        .font(.system(size: 14))
                        .foregroundColor(MVTheme.muted)
                }
                
                Spacer()
                
                Menu {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            withAnimation {
                                themeManager.setTheme(theme)
                            }
                        } label: {
                            HStack {
                                Text(theme.localizedName(using: languageManager))
                                if themeManager.currentTheme == theme {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(themeManager.currentTheme.localizedName(using: languageManager))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MVTheme.foreground)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(MVTheme.muted)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MVTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MVTheme.border, lineWidth: 1)
                    )
                }
            }
            .padding(.bottom, 16)
            
            // 分割线
            Divider()
                .background(MVTheme.border)
                .padding(.vertical, 16)
            
            // 关于部分
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.about.title".localized(using: languageManager))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(MVTheme.foreground)
                
                HStack {
                    Text("settings.version".localized(using: languageManager))
                        .font(.system(size: 14))
                        .foregroundColor(MVTheme.muted)
                    Spacer()
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text(version)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MVTheme.foreground)
                    }
                }
            }
            .padding(.bottom, 16)
            
            // 分割线
            Divider()
                .background(MVTheme.border)
                .padding(.vertical, 16)
            
            // 作者签名
            HStack {
                Spacer()
                Text("created by xty")
                    .font(.system(size: 12))
                    .foregroundColor(MVTheme.muted)
                Spacer()
            }
            .padding(.top, 8)
        }
    }
}
