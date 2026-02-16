import SwiftUI

struct SoftCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(MVTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: MVTheme.shadowColor, radius: 10, x: 0, y: 6)
    }
}
