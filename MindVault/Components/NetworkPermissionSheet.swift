import SwiftUI

struct NetworkPermissionSheet: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    let title: String?
    let subtitle: String?
    let iconName: String
    let privacyTitle: String?
    let privacySubtitle: String?
    let allowButtonTitle: String?
    let cancelButtonTitle: String?
    let onAllow: () -> Void
    let onCancel: () -> Void
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        iconName: String = "cloud.fill",
        privacyTitle: String? = nil,
        privacySubtitle: String? = nil,
        allowButtonTitle: String? = nil,
        cancelButtonTitle: String? = nil,
        onAllow: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.privacyTitle = privacyTitle
        self.privacySubtitle = privacySubtitle
        self.allowButtonTitle = allowButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.onAllow = onAllow
        self.onCancel = onCancel
    }
    
    private var displayTitle: String {
        title ?? "network.title".localized(using: languageManager)
    }
    
    private var displaySubtitle: String {
        subtitle ?? "network.subtitle".localized(using: languageManager)
    }
    
    private var displayPrivacyTitle: String {
        privacyTitle ?? "network.privacy.title".localized(using: languageManager)
    }
    
    private var displayPrivacySubtitle: String {
        privacySubtitle ?? "network.privacy.subtitle".localized(using: languageManager)
    }
    
    private var displayAllowButtonTitle: String {
        allowButtonTitle ?? "network.allow".localized(using: languageManager)
    }
    
    private var displayCancelButtonTitle: String {
        cancelButtonTitle ?? "common.cancel".localized(using: languageManager)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 图标
                Image(systemName: iconName)
                    .font(.system(size: 64))
                    .foregroundStyle(MVTheme.gradient)
                    .padding(.top, 40)
                
                // 标题和说明
                VStack(spacing: 12) {
                    Text(displayTitle)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(MVTheme.foreground)
                    
                    Text(displaySubtitle)
                        .font(.system(size: 18))
                        .foregroundColor(MVTheme.muted)
                }
                
                // 隐私说明
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(MVTheme.primary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayPrivacyTitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(MVTheme.foreground)
                            
                            Text(displayPrivacySubtitle)
                                .font(.system(size: 14))
                                .foregroundColor(MVTheme.muted)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MVTheme.primary.opacity(0.1))
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 按钮
                VStack(spacing: 12) {
                    Button {
                        onAllow()
                    } label: {
                        Text(displayAllowButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(MVTheme.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    Button {
                        onCancel()
                    } label: {
                        Text(displayCancelButtonTitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MVTheme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(MVTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .id(languageManager.currentLanguage.id)
    }
}

#Preview {
    NetworkPermissionSheet(
        onAllow: {
            print("允许使用网络")
        },
        onCancel: {
            print("取消")
        }
    )
    .environmentObject(LanguageManager.shared)
}
