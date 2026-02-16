import SwiftUI
import Speech

/// 模型类型枚举
enum ModelType: String, CaseIterable {
    case local
    case stepfun
    
    var localized: String {
        switch self {
        case .local:
            return "chat.model.local".localized
        case .stepfun:
            return "chat.model.stepfun".localized
        }
    }
    
    var icon: String {
        switch self {
        case .local:
            return "cpu"
        case .stepfun:
            return "cloud"
        }
    }
}

struct ChatView: View {
    @State private var openRouterService: OpenRouterService
    @State private var llamaModel = LlamaModel()
    @AppStorage("selectedModel") private var selectedModel: ModelType = .local
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isGenerating: Bool = false
    @State private var currentResponse: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var currentTask: Task<Void, Never>?
    @State private var showNetworkPermissionAlert: Bool = false
    @AppStorage("hasAskedNetworkPermission") private var hasAskedNetworkPermission: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showSpeechPermissionAlert: Bool = false
    @State private var shouldAutoSendAfterRecording: Bool = false
    
    init() {
        _openRouterService = State(initialValue: OpenRouterService(
            apiKey: AppConfig.OpenRouter.apiKey,
            modelName: AppConfig.OpenRouter.defaultModelName
        ))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if messages.isEmpty {
                                emptyState
                                    .fadeIn()
                            } else {
                                ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                    // 如果是最后一条消息且是assistant消息且正在生成，显示加载动画
                                    let isLastMessage = index == messages.count - 1
                                    let shouldShowGenerating = isGenerating && isLastMessage && message.role == .assistant
                                    MessageBubble(
                                        message: message,
                                        isGenerating: shouldShowGenerating
                                    )
                                    .id(index)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    ))
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 20)
                        .animation(AnimationHelpers.smoothSpring, value: messages.count)
                    }
                    .onChange(of: messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: currentResponse) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isInputFocused) { newValue in
                        // 当输入框聚焦且不在生成消息时，滚动到底部
                        if newValue && !isGenerating {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onChange(of: isGenerating) { newValue in
                        // 当消息处理完成（从生成中变为完成）且输入框已聚焦时，滚动到底部
                        if !newValue && isInputFocused {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                // 输入区域
                inputArea
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        // 点击输入框以外的任何区域时收起键盘
                        isInputFocused = false
                    }
            )
        }
        .background(MVTheme.background.ignoresSafeArea())
        .navigationTitle("chat.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                modelToggleButton
            }
        }
        .sheet(isPresented: $showNetworkPermissionAlert) {
            networkPermissionSheet
        }
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
        .onChange(of: speechRecognizer.recognizedText) { _, newText in
            // 将识别的文本直接设置到输入框中
            if !newText.isEmpty {
                inputText = newText
            }
            
            // 如果停止录音后识别文本更新，且应该自动发送，则发送
            if shouldAutoSendAfterRecording && !speechRecognizer.isRecording {
                // 延迟一小段时间确保文本已更新
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                    if shouldAutoSendAfterRecording {
                        shouldAutoSendAfterRecording = false
                        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !isGenerating {
                            await MainActor.run {
                                sendMessage()
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: speechRecognizer.isRecording) { _, isRecording in
            if isRecording {
                // 开始录音时，清空之前的识别文本
                speechRecognizer.clearText()
            } else {
                // 停止录音时，如果应该自动发送，立即尝试发送
                if shouldAutoSendAfterRecording {
                    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !isGenerating {
                        shouldAutoSendAfterRecording = false
                        sendMessage()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // 当应用进入后台时，取消正在进行的生成任务和停止录音
            if oldPhase == .active && (newPhase == .inactive || newPhase == .background) {
                // 停止录音
                if speechRecognizer.isRecording {
                    speechRecognizer.stopRecording()
                    shouldAutoSendAfterRecording = false
                }
                
                // 取消生成任务
                if isGenerating {
                    currentTask?.cancel()
                    currentTask = nil
                    llamaModel.stopGenerating()
                    // 如果占位符消息为空，移除它
                    if let lastIndex = messages.indices.last,
                       messages[lastIndex].role == .assistant,
                       messages[lastIndex].content.isEmpty {
                        messages.removeLast()
                    } else if let lastIndex = messages.indices.last,
                              messages[lastIndex].role == .assistant {
                        // 如果有部分内容，保留它
                        messages[lastIndex] = Message(role: .assistant, content: currentResponse)
                    }
                    isGenerating = false
                    currentResponse = ""
                }
            }
        }
    }
    
    private var modelToggleButton: some View {
        Menu {
            ForEach(ModelType.allCases, id: \.self) { modelType in
                Button {
                    handleModelSelection(modelType)
                } label: {
                    HStack {
                        Image(systemName: modelType.icon)
                        Text(modelType.localized)
                        if selectedModel == modelType {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedModel.icon)
                    .font(.system(size: 14))
                Text(selectedModel.localized)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(MVTheme.primary)
        }
    }
    
    private func handleModelSelection(_ modelType: ModelType) {
        // 如果切换到 DeepSeek 且尚未询问过网络权限
        if modelType == .stepfun && !hasAskedNetworkPermission {
            showNetworkPermissionAlert = true
        } else {
            selectedModel = modelType
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(MVTheme.gradient)
            
            VStack(spacing: 8) {
                Text("chat.empty.title".localized)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(MVTheme.foreground)
                
                Text("chat.empty.message".localized)
                    .font(.system(size: 16))
                    .foregroundColor(MVTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 语音输入按钮（输入框未聚焦时显示）
                if !isInputFocused {
                    speechInputButton
                }
                
                // 输入框
                HStack(spacing: 8) {
                    TextField("chat.input.placeholder".localized, text: $inputText, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(MVTheme.foreground)
                        .lineLimit(1...2)
                        .focused($isInputFocused)
                        .disabled(isGenerating)
                        .onSubmit {
                            // 回车键发送
                            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating {
                                sendMessage()
                            }
                        }
                    
                    if !inputText.isEmpty {
                        Button {
                            inputText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(MVTheme.muted)
                        }
                    }
                    
                    // 发送按钮
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: (isGenerating && selectedModel == .stepfun) ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                (isGenerating && selectedModel == .local) || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AnyShapeStyle(MVTheme.muted.opacity(0.5))
                                : AnyShapeStyle(MVTheme.gradient)
                            )
                    }
                    .disabled((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating) || (isGenerating && selectedModel == .local))
                    .buttonStyle(PressableScaleStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(MVTheme.surface)
                        .shadow(color: MVTheme.shadowColor, radius: 8, x: 0, y: 2)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
    
    private var speechInputButton: some View {
        Button {
            // 点击切换录音状态
            if speechRecognizer.isRecording {
                // 正在录音，停止录音并发送
                shouldAutoSendAfterRecording = true
                speechRecognizer.stopRecording()
            } else {
                // 未录音，开始录音
                if !isGenerating {
                    shouldAutoSendAfterRecording = true
                    handleSpeechStart()
                }
            }
        } label: {
            Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 20))
                .foregroundColor(speechRecognizer.isRecording ? .white : MVTheme.foreground)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(speechRecognizer.isRecording ? Color.red : MVTheme.surface)
                )
                .overlay(
                    Circle()
                        .stroke(speechRecognizer.isRecording ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
                )
                .scaleEffect(speechRecognizer.isRecording ? 1.1 : 1.0)
                .animation(AnimationHelpers.quickSpring, value: speechRecognizer.isRecording)
                .shadow(color: MVTheme.shadowColor, radius: 8, x: 0, y: 2)
        }
        .disabled(isGenerating)
    }
    
    private func handleSpeechStart() {
        guard !isGenerating && !speechRecognizer.isRecording else { return }
        
        // 开始录音
        Task {
            do {
                try await speechRecognizer.startRecording()
            } catch {
                if speechRecognizer.authorizationStatus == .denied || speechRecognizer.authorizationStatus == .restricted {
                    showSpeechPermissionAlert = true
                } else {
                    // 静默处理其他错误，不显示给用户
                    // speechRecognizer.errorMessage = error.localizedDescription
                    // showSpeechErrorAlert = true
                }
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !isGenerating else {
            if isGenerating {
                // 取消当前任务
                currentTask?.cancel()
                currentTask = nil
                isGenerating = false
                // 处理占位符消息：如果有内容则保留，如果为空则移除
                if let lastIndex = messages.indices.last,
                   messages[lastIndex].role == .assistant {
                    if !currentResponse.isEmpty {
                        messages[lastIndex] = Message(role: .assistant, content: currentResponse)
                    } else {
                        messages.removeLast()
                    }
                }
                currentResponse = ""
            }
            return
        }
        
        // 添加用户消息
        let userMessage = Message(role: .user, content: trimmed)
        withAnimation(AnimationHelpers.smoothSpring) {
            messages.append(userMessage)
        }
        inputText = ""
        isGenerating = true
        currentResponse = ""
        
        // 立即添加一个空的 assistant 消息占位符，让用户知道 AI 正在响应
        let placeholderMessage = Message(role: .assistant, content: "")
        withAnimation(AnimationHelpers.smoothSpring) {
            messages.append(placeholderMessage)
        }
        let assistantMessageIndex = messages.count - 1
        
        // 生成AI回复（使用异步方法）
        // 注意：LlamaModel 现在在专门的 GPU 队列上执行，不会阻塞主线程
        let task = Task { @MainActor in
            do {
                let response: String
                
                // 根据选择的模型类型调用不同的服务
                if selectedModel == .local {
                    // 使用内置 Llama 模型（流式输出）
                    // GPU 操作在专门的队列上执行，不会阻塞主线程
                    let model = llamaModel
                    var messageList = Array(messages.dropLast()) // 排除刚添加的占位符消息
                    
                    // 为了模型输入限制，只传入最后15条消息（约8个消息对）
                    // 保留系统消息（如果存在），然后取最后15条消息
                    var systemMessage: Message? = nil
                    if messageList.first?.role == .system {
                        systemMessage = messageList.first
                        messageList = Array(messageList.dropFirst())
                    }
                    // 取最后15条消息
                    if messageList.count > 15 {
                        messageList = Array(messageList.suffix(15))
                    }
                    // 如果有系统消息，将其放在开头
                    if let systemMsg = systemMessage {
                        messageList.insert(systemMsg, at: 0)
                    }
                    
                    // 使用本地变量累积响应
                    var localAccumulated = ""
                    response = try await model.generate(messages: messageList) { token in
                        // 检查任务是否已取消
                        guard !Task.isCancelled else { return }
                        
                        localAccumulated += token
                        // 在主线程上更新 UI（onToken 回调已经在 MainActor 上下文中）
                        let accumulated = localAccumulated
                        self.currentResponse = accumulated
                        // 更新占位符消息的内容
                        if self.messages.indices.contains(assistantMessageIndex) {
                            self.messages[assistantMessageIndex] = Message(role: .assistant, content: accumulated)
                        }
                    }
                } else {
                    // 使用 DeepSeek（OpenRouter）（流式输出）
                    var accumulatedResponse = ""
                    var messageList = Array(messages.dropLast()) // 排除刚添加的占位符消息
                    // 确保系统提示词在消息列表开头（如果还没有）
                    if messageList.first?.role != .system {
                        let systemMessage = Message(role: .system, content: AppConfig.SystemPrompt.openRouter)
                        messageList.insert(systemMessage, at: 0)
                    }
                    response = try await openRouterService.generate(messages: messageList) { token in
                        // 检查任务是否已取消
                        guard !Task.isCancelled else { return }
                        
                        accumulatedResponse += token
                        // 立即在主线程更新 UI，使用 MainActor 确保线程安全
                        Task { @MainActor in
                            guard !Task.isCancelled else { return }
                            self.currentResponse = accumulatedResponse
                            // 更新占位符消息的内容
                            if self.messages.indices.contains(assistantMessageIndex) {
                                self.messages[assistantMessageIndex] = Message(role: .assistant, content: accumulatedResponse)
                            }
                        }
                    }
                }
                
                // 检查任务是否已取消
                guard !Task.isCancelled else {
                    // 如果任务被取消，移除空的占位符消息
                    isGenerating = false
                    if messages.indices.contains(assistantMessageIndex),
                       messages[assistantMessageIndex].content.isEmpty {
                        messages.remove(at: assistantMessageIndex)
                    }
                    currentResponse = ""
                    currentTask = nil
                    return
                }
                
                isGenerating = false
                // 确保最终响应被更新到占位符消息
                let finalResponse = currentResponse.isEmpty ? response : currentResponse
                if !finalResponse.isEmpty && messages.indices.contains(assistantMessageIndex) {
                    messages[assistantMessageIndex] = Message(role: .assistant, content: finalResponse)
                } else if !finalResponse.isEmpty {
                    // 如果索引无效，则添加新消息（兜底逻辑）
                    messages.append(Message(role: .assistant, content: finalResponse))
                }
                currentResponse = ""
                currentTask = nil
            } catch {
                isGenerating = false
                currentResponse = ""
                currentTask = nil
                // 只有在任务未被取消时才显示错误
                if !Task.isCancelled {
                    let errorMessage = "chat.error".localized(with: error.localizedDescription)
                    // 更新占位符消息为错误消息
                    if messages.indices.contains(assistantMessageIndex) {
                        messages[assistantMessageIndex] = Message(role: .assistant, content: errorMessage)
                    } else {
                        // 如果索引无效，则添加新消息（兜底逻辑）
                        messages.append(Message(role: .assistant, content: errorMessage))
                    }
                } else {
                    // 如果任务被取消且占位符消息为空，移除它
                    if messages.indices.contains(assistantMessageIndex),
                       messages[assistantMessageIndex].content.isEmpty {
                        messages.remove(at: assistantMessageIndex)
                    }
                }
            }
        }
        
        currentTask = task
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(AnimationHelpers.smoothEaseOut) {
            if let lastIndex = messages.indices.last {
                proxy.scrollTo(lastIndex, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Network Permission
    
    private var networkPermissionSheet: some View {
        NetworkPermissionSheet(
            onAllow: {
                requestNetworkPermission()
            },
            onCancel: {
                showNetworkPermissionAlert = false
            }
        )
    }
    
    private func requestNetworkPermission() {
        hasAskedNetworkPermission = true
        selectedModel = .stepfun
        showNetworkPermissionAlert = false
        
        // 触发系统网络权限弹窗（通过发送一个简单的网络请求）
        Task {
            await triggerNetworkPermissionRequest()
        }
    }
    
    private func triggerNetworkPermissionRequest() async {
        // 发送一个简单的网络请求来触发系统权限弹窗
        // 使用 OpenRouter 的 API 端点，但只发送一个轻量级的请求
        guard let url = URL(string: AppConfig.OpenRouter.modelsURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AppConfig.OpenRouter.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5.0 // 设置较短的超时时间
        
        do {
            // 这个请求会被系统拦截，触发网络权限弹窗
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            // 忽略错误，我们只是用来触发权限弹窗
            // 实际的 API 调用会在用户发送消息时进行
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    var isGenerating: Bool = false
    
    @State private var animateDots = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // AI头像
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(MVTheme.gradient)
                    .frame(width: 28, height: 28)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // 使用 markdown 渲染 AI 消息，用户消息保持原样
                if message.role == .assistant {
                    // 如果内容为空，显示占位符文本
                    let displayContent = message.content.isEmpty ? "chat.generating".localized : message.content
                    
                    // 创建一个支持换行和 Markdown 的文本视图
                    let combinedText = Text(buildAttributedString(from: displayContent))
                    
                    combinedText
                        .font(.system(size: 18))
                        .foregroundColor(message.content.isEmpty ? MVTheme.muted : MVTheme.foreground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            AnyShapeStyle(.ultraThinMaterial.opacity(0.8))
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    AnyShapeStyle(LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: MVTheme.shadowColor,
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                } else {
                    Text(message.content)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            AnyShapeStyle(MVTheme.gradient)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    AnyShapeStyle(Color.clear),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: MVTheme.primary.opacity(0.2),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                }
                
                if isGenerating {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(MVTheme.muted.opacity(0.6))
                                .frame(width: 6, height: 6)
                                .scaleEffect(animateDots ? (index == 0 ? 1.2 : (index == 1 ? 1.0 : 0.8)) : (index == 0 ? 0.8 : (index == 1 ? 1.0 : 1.2)))
                                .opacity(animateDots ? (index == 0 ? 1.0 : (index == 1 ? 0.7 : 0.5)) : (index == 0 ? 0.5 : (index == 1 ? 0.7 : 1.0)))
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            animateDots = true
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
    
    // 辅助函数：构建支持 Markdown 和换行的 AttributedString
    private func buildAttributedString(from content: String) -> AttributedString {
        let lines = content.components(separatedBy: "\n")
        var combinedAttributedString = AttributedString()
        
        for (index, line) in lines.enumerated() {
            if index > 0 {
                // 在每行之间添加换行符（除了第一行）
                combinedAttributedString.append(AttributedString("\n"))
            }
            
            if line.isEmpty {
                // 空行：只添加换行符（已经在上面添加了）
                continue
            } else {
                // 非空行：尝试渲染 Markdown
                if let attributedLine = try? AttributedString(markdown: line) {
                    combinedAttributedString.append(attributedLine)
                } else {
                    combinedAttributedString.append(AttributedString(line))
                }
            }
        }
        
        return combinedAttributedString
    }
}
