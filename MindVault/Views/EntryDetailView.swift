import SwiftUI

struct EntryDetailView: View {
    @ObservedObject var store: DiaryStore
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    @State private var selectedImageIndex: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14))
                        .foregroundColor(MVTheme.muted)
                    Spacer()
                    if let tag = entry.tag {
                        tagBadge(tag: tag)
                    }
                }
                .fadeIn()
                Text(entry.title.replacingOccurrences(of: #"\r\n|\r|\n"#, with: " ", options: .regularExpression).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(MVTheme.foreground)
                    .fadeIn()

                // 图片预览区域：放在标题下方，和撰写界面保持一致的结构（详情里尺寸更大一些）
                if !entry.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(entry.images.enumerated()), id: \.element.id) { index, image in
                                if let uiImage = UIImage(data: image.data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 150)
                                        .clipped()
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                                        .onTapGesture {
                                            selectedImageIndex = index
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .fadeIn()
                }

                Text(entry.content)
                    .font(.system(size: 17))
                    .foregroundColor(MVTheme.foreground)
                    .lineSpacing(8)
                    .fadeIn()

                if !entry.isAnalyzing && !isAnalysisFailed {
                    sentimentCard
                        .fadeIn()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(MVTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("entry.detail.title".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(MVTheme.foreground)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("entry.detail.delete".localized) { showDelete = true }
                    .foregroundColor(MVTheme.error)
            }
        }
        .alert("entry.detail.delete.alert.title".localized, isPresented: $showDelete) {
            Button("entry.detail.delete.alert.cancel".localized, role: .cancel) {}
            Button("entry.detail.delete.alert.confirm".localized, role: .destructive) {
                store.deleteEntry(entry)
                dismiss()
            }
        } message: {
            Text("entry.detail.delete.alert.message".localized)
        }
        .fullScreenCover(item: Binding(
            get: { selectedImageIndex },
            set: { selectedImageIndex = $0 }
        )) { index in
            ImageGalleryView(
                images: entry.images,
                currentIndex: index,
                onDismiss: { selectedImageIndex = nil }
            )
        }
    }

    private func tagBadge(tag: DiaryTag) -> some View {
        HStack(spacing: 4) {
            Text(tag.emoji)
                .font(.system(size: 12))
            Text(tag.localizedName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(MVTheme.primary)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(MVTheme.primary.opacity(0.12))
        )
    }

    private var isAnalysisFailed: Bool {
        entry.sentiment?.summary == "entry.analysis.failed"
    }

    private var sentimentCard: some View {
        let display = SentimentDisplay.from(sentiment: entry.sentiment)
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    AnimatedEmojiView(emoji: display.emoji, imageName: display.imageName, size: 42)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(display.localizedLabel)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(MVTheme.foreground)
                            Text(display.scoreText)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(MVTheme.primary)
                        }
                        Text(display.localizedSummary)
                            .font(.system(size: 13))
                            .foregroundColor(MVTheme.muted)
                    }
                }
                SentimentBar(score: display.score)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(MVTheme.gradient, lineWidth: 1)
        )
        .padding(.top, 16)
    }
}

// MARK: - Image Gallery View
struct ImageGalleryView: View {
    let images: [DiaryImage]
    let currentIndex: Int
    let onDismiss: () -> Void
    
    @State private var selectedIndex: Int
    
    init(images: [DiaryImage], currentIndex: Int, onDismiss: @escaping () -> Void) {
        self.images = images
        self.currentIndex = currentIndex
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: currentIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Top bar with close button
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding()
                .zIndex(1)
                
                // Image gallery with TabView
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        if let uiImage = UIImage(data: image.data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .tag(index)
                                .onTapGesture {
                                    onDismiss()
                                }
                        }
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }
}

// MARK: - Int Identifiable Extension
extension Int: Identifiable {
    public var id: Int { self }
}
