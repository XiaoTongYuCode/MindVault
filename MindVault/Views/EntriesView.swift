import SwiftUI

struct EntriesView: View {
    @ObservedObject var store: DiaryStore
    @Binding var showCompose: Bool
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            header
                .fadeIn()
            if store.entries.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "entries.empty.title".localized(using: languageManager),
                    message: "entries.empty.message".localized(using: languageManager),
                    actionTitle: "entries.empty.action".localized(using: languageManager),
                    action: { showCompose = true }
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                            NavigationLink(value: entry) {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .listItemAnimation(index: index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(MVTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(for: DiaryEntry.self) { entry in
            EntryDetailView(store: store, entry: entry)
        }
        .id(languageManager.currentLanguage.id)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("entries.title".localized(using: languageManager))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(MVTheme.foreground)
                Text("entries.subtitle".localized(using: languageManager))
                    .font(.system(size: 14))
                    .foregroundColor(MVTheme.muted)
            }
            Spacer()
            Button {
                showCompose = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("entries.new.button".localized(using: languageManager))
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(MVTheme.gradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressableScaleStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
