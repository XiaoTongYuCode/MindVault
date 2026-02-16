import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(MVTheme.primary)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MVTheme.foreground)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(MVTheme.muted)
                .multilineTextAlignment(.center)
            Button(actionTitle) { action() }
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(MVTheme.gradient)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .buttonStyle(PressableScaleStyle())
        }
        .padding(.horizontal, 32)
    }
}
