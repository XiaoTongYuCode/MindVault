import SwiftUI
import Speech
import PhotosUI

struct ComposeView: View {
    @ObservedObject var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var imageDatas: [Data] = []
    @State private var showEmptyAlert = false
    @State private var showSpeechPermissionAlert = false
    @State private var showSpeechErrorAlert = false
    @State private var contentBeforeRecording: String = "" // 录音开始时的内容
    @FocusState private var isContentFocused: Bool
    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        NavigationStack {
            mainContent
        }
    }

    /// 主体内容视图，拆出来降低单个表达式复杂度，避免编译器 type-check 超时
    private var mainContent: some View {
        editorCore
            .onAppear {
                // 加载草稿
                if let draft = store.loadDraft() {
                    title = draft.title
                    content = draft.content
                    imageDatas = draft.images
                }
                // 需要一点点延迟，确保视图已经在层级中再请求焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isContentFocused = true
                }
            }
            .onChange(of: title) { _, newValue in
                // 自动保存草稿
                store.saveDraft(title: newValue, content: content, images: imageDatas)
            }
            .onChange(of: content) { _, newValue in
                // 自动保存草稿
                store.saveDraft(title: title, content: newValue, images: imageDatas)
            }
            .onChange(of: imageDatas) { _, newImages in
                // 图片变更时也自动保存草稿
                store.saveDraft(title: title, content: content, images: newImages)
            }
            .onChange(of: speechRecognizer.recognizedText) { _, newText in
                // 将识别的文本追加到内容中
                if !newText.isEmpty {
                    // 基于录音开始时的内容，加上新识别的文本
                    if contentBeforeRecording.isEmpty {
                        content = newText
                    } else {
                        // 如果录音开始时有内容，追加空格和新识别的文本
                        let trimmed = contentBeforeRecording.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            content = contentBeforeRecording + (contentBeforeRecording.hasSuffix(" ") ? "" : " ") + newText
                        } else {
                            content = newText
                        }
                    }
                }
            }
            .onChange(of: speechRecognizer.isRecording) { _, isRecording in
                if isRecording {
                    // 开始录音时，保存当前内容
                    contentBeforeRecording = content
                    speechRecognizer.clearText()
                } else {
                    // 停止录音时，清空临时变量
                    contentBeforeRecording = ""
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    var newDatas: [Data] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            newDatas.append(data)
                        }
                    }
                    await MainActor.run {
                        imageDatas.append(contentsOf: newDatas)
                        selectedItems.removeAll()
                    }
                }
            }
            .navigationTitle("compose.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("compose.cancel".localized) { handleCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("compose.save".localized) { handleSave() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MVTheme.primary)
                }
            }
            .alert("compose.empty.alert".localized, isPresented: $showEmptyAlert) {
                Button("compose.empty.alert.ok".localized, role: .cancel) {}
            }
            // 退出时不再弹确认框，直接在 handleCancel 中保存草稿并关闭
            .alert("compose.speech.permission.title".localized, isPresented: $showSpeechPermissionAlert) {
                Button("compose.speech.permission.settings".localized) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("compose.cancel".localized, role: .cancel) {}
            } message: {
                Text("compose.speech.permission.message".localized)
            }
            .alert("compose.speech.error".localized, isPresented: $showSpeechErrorAlert) {
                Button("compose.empty.alert.ok".localized, role: .cancel) {
                    speechRecognizer.errorMessage = nil
                }
            } message: {
                if let errorMessage = speechRecognizer.errorMessage {
                    Text(errorMessage)
                }
            }
            .onChange(of: speechRecognizer.errorMessage) { _, newValue in
                showSpeechErrorAlert = newValue != nil
            }
    }

    /// 编辑区域主体：标题输入、图片预览、正文 + 底部工具条
    private var editorCore: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                TextField("compose.title.placeholder".localized, text: $title)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal, 8)
                Rectangle()
                    .fill(MVTheme.border)
                    .frame(height: 1)
            }
            .fadeIn()

            // 已选图片预览区域（可选，横向滚动）
            if !imageDatas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(imageDatas.enumerated()), id: \.offset) { index, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipped()
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            imageDatas.remove(at: index)
                                        } label: {
                                            Label("compose.image.remove".localized, systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 100)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(AnimationHelpers.smoothSpring, value: imageDatas.count)
            }

            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("compose.content.placeholder".localized)
                        .font(.system(size: 18))
                        .foregroundColor(MVTheme.muted)
                        .padding(.top, 8)
                        .padding(.leading, 6)
                }
                TextEditor(text: $content)
                    .font(.system(size: 18))
                    .scrollContentBackground(.hidden) // 隐藏系统默认背景
                    .background(Color.clear) // 设为透明背景
                    .focused($isContentFocused)
                    .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 4)
            .fadeIn()
            .overlay(alignment: .bottom) {
                HStack(spacing: 16) {
                    // 语音输入按钮
                    Button {
                        handleSpeechButtonTap()
                    } label: {
                        Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 20))
                            .foregroundColor(speechRecognizer.isRecording ? .red : MVTheme.foreground)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(speechRecognizer.isRecording ? Color.red.opacity(0.1) : MVTheme.background)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                            .scaleEffect(speechRecognizer.isRecording ? 1.1 : 1.0)
                    }

                    // 选图按钮
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 9,
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(MVTheme.foreground)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(MVTheme.background)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                    }
                }
                .padding(.bottom, 12)
                .animation(AnimationHelpers.quickSpring, value: speechRecognizer.isRecording)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .background(MVTheme.background.ignoresSafeArea())
    }

    private func handleSave() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyAlert = true
            return
        }
        store.addEntry(title: title, content: content, images: imageDatas)
        // 保存成功后清除草稿
        store.clearDraft()
        dismiss()
    }

    private func handleCancel() {
        // 停止语音识别
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.isEmpty && trimmedTitle.isEmpty && imageDatas.isEmpty {
            // 文本和图片都为空时直接退出，清除草稿
            store.clearDraft()
        } else {
            // 有文本或图片时保存草稿，方便下次继续编辑
            store.saveDraft(title: title, content: content, images: imageDatas)
        }
        
        // 统一在最后关闭页面
        dismiss()
    }
    
    private func handleSpeechButtonTap() {
        if speechRecognizer.isRecording {
            // 停止录音
            speechRecognizer.stopRecording()
        } else {
            // 开始录音
            Task {
                do {
                    try await speechRecognizer.startRecording()
                } catch {
                    if speechRecognizer.authorizationStatus == .denied || speechRecognizer.authorizationStatus == .restricted {
                        showSpeechPermissionAlert = true
                    } else {
                        speechRecognizer.errorMessage = error.localizedDescription
                        showSpeechErrorAlert = true
                    }
                }
            }
        }
    }
}
