import SwiftUI

struct EntriesView: View {
    @ObservedObject var store: DiaryStore
    @Binding var showCompose: Bool
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var searchText: String = ""
    @State private var selectedTag: DiaryTag? = nil
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .fadeIn()
            
            // Search and Filter Section
            if !store.entries.isEmpty {
                VStack(spacing: 12) {
                    searchBar
                    filterBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .fadeIn()
            }
            
            if filteredEntries.isEmpty {
                Spacer()
                if store.entries.isEmpty {
                    EmptyStateView(
                        title: "entries.empty.title".localized(using: languageManager),
                        message: "entries.empty.message".localized(using: languageManager),
                        actionTitle: "entries.empty.action".localized(using: languageManager),
                        action: { showCompose = true }
                    )
                } else {
                    EmptyStateView(
                        title: "entries.empty.title".localized(using: languageManager),
                        message: "entries.filter.noResults".localized(using: languageManager),
                        actionTitle: nil,
                        action: nil
                    )
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
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
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(MVTheme.background.ignoresSafeArea())
        .simultaneousGesture(
            TapGesture().onEnded {
                if isSearchFocused {
                    isSearchFocused = false
                }
            }
        )
        .navigationBarHidden(true)
        .navigationDestination(for: DiaryEntry.self) { entry in
            EntryDetailView(store: store, entry: entry)
        }
        .id(languageManager.currentLanguage.id)
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [DiaryEntry] {
        var entries = store.entries
        
        // Filter by search text (title + content)
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            entries = entries.filter { entry in
                entry.title.lowercased().contains(searchLower) ||
                entry.content.lowercased().contains(searchLower)
            }
        }
        
        // Filter by selected tag
        if let selectedTag = selectedTag {
            entries = entries.filter { $0.tag == selectedTag }
        }
        
        return entries
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(MVTheme.muted)
            
            TextField(
                "entries.search.placeholder".localized(using: languageManager),
                text: $searchText
            )
            .font(.system(size: 15))
            .foregroundColor(MVTheme.foreground)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(MVTheme.muted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MVTheme.surface)
                .shadow(color: MVTheme.shadowColor, radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All" filter button
                FilterTagButton(
                    title: "entries.filter.all".localized(using: languageManager),
                    emoji: nil,
                    isSelected: selectedTag == nil,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTag = nil
                        }
                    }
                )
                
                // Tag filter buttons
                ForEach(DiaryTag.allCases, id: \.self) { tag in
                    FilterTagButton(
                        title: tag.localizedName,
                        emoji: tag.emoji,
                        isSelected: selectedTag == tag,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("entries.title".localized(using: languageManager))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(MVTheme.foreground)
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

// MARK: - Filter Tag Button Component

struct FilterTagButton: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : MVTheme.foreground)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Group {
                    if isSelected {
                        MVTheme.gradient
                    } else {
                        MVTheme.surface
                    }
                }
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PressableScaleStyle())
    }
}
