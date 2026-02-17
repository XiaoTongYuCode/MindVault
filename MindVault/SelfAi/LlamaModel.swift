//
//  LlamaModel.swift
//  MindVault
//
//  Created by XTY on 2026/2/12.
//

import Foundation
import LlamaSwift
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 消息角色
enum MessageRole: String {
    case system
    case user
    case assistant
}

/// 消息结构
struct Message {
    let role: MessageRole
    let content: String
}

/// 模型配置
struct ModelConfig {
    let modelName: String
    let temperature: Float
    let topP: Float
    let maxTokens: Int
    let contextSize: UInt32
    let batchSize: UInt32
    let systemPrompt: String
    let nGpuLayers: Int32  // GPU 层数，设置为 99 表示尽可能多的层在 GPU 上运行
    
    init(
        modelName: String? = nil,
        temperature: Float? = nil,
        topP: Float? = nil,
        maxTokens: Int? = nil,
        contextSize: UInt32? = nil,
        batchSize: UInt32? = nil,
        systemPrompt: String? = nil,
        nGpuLayers: Int32? = nil
    ) {
        // 直接使用常量作为默认值，避免在初始化过程中再次访问 `ModelConfig.default`
        self.modelName = modelName ?? AppConfig.LocalModel.defaultModelName
        self.temperature = temperature ?? 0.8
        self.topP = topP ?? 0.9
        self.maxTokens = maxTokens ?? 1000
        self.contextSize = contextSize ?? 2048
        self.batchSize = batchSize ?? 512
        self.systemPrompt = systemPrompt ?? AppConfig.SystemPrompt.localModel
        // 默认设置为 99，确保所有层都尽可能在 GPU 上运行（如果设备支持 Metal）
        self.nGpuLayers = nGpuLayers ?? 99
    }
    
    /// 默认配置
    static let `default` = ModelConfig()
}

/// Llama 模型封装类，提供简洁的输入输出接口
class LlamaModel {
    // MARK: - Properties
    
    #if targetEnvironment(simulator)
    /// 是否运行在模拟器环境
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif
    
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var isModelLoaded = false
    private let config: ModelConfig
    private let utf8Accumulator = UTF8Accumulator()
    private var isGenerating = false  // 标记是否正在生成
    
    // 专门的串行队列用于执行 GPU 操作，避免阻塞主线程
    private let gpuQueue = DispatchQueue(label: "com.mindvault.llama.gpu", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(config: ModelConfig = .default) {
        self.config = config
        // 模拟器环境下不初始化真实 llama 后端，避免二进制 / 硬件依赖问题
        if !isSimulator {
            llama_backend_init()
        }
    }
    
    /// 便捷初始化方法，允许直接传入 temperature 和 systemPrompt
    convenience init(temperature: Float? = nil, systemPrompt: String? = nil) {
        let config = ModelConfig(
            temperature: temperature,
            systemPrompt: systemPrompt
        )
        self.init(config: config)
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// 预热模型：只加载模型与基础上下文，不进行实际推理，尽量减小预热开销
    func warmUp() {
        // 模拟器环境下不做任何事情，避免误触发真实后端逻辑
        if isSimulator {
            return
        }
        do {
            try ensureModelLoaded()
        } catch {
            // 预热失败不应影响主流程，这里仅做调试输出
            print("LlamaModel warmUp failed: \(error)")
        }
    }
    
    /// 生成响应（流式输出）
    /// - Parameters:
    ///   - messages: 消息历史（包括系统消息、用户消息和助手消息）
    ///   - onToken: 每生成一个完整字符时调用的回调（异步）
    /// - Returns: 完整的响应文本
    func generate(messages: [Message], onToken: @escaping (String) async -> Void) async throws -> String {
        // 模拟器环境：不调用真实模型，返回 mock 文本，方便在模拟器上开发 / 调试 UI
        if isSimulator {
            return try await mockResponseStreaming(for: messages, onToken: onToken)
        }
        
        // 检查应用状态，如果不在前台则抛出错误
        guard isApplicationActive() else {
            throw ModelError.applicationInBackground
        }
        
        // 标记开始生成
        isGenerating = true
        defer { isGenerating = false }
        
        // 在 GPU 队列上执行模型加载和初始化操作
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            gpuQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ModelError.modelNotLoaded)
                    return
                }
                
                do {
                    // 确保模型已加载
                    try self.ensureModelLoaded()
                    
                    // 重新创建上下文以确保 KV cache 从 0 开始
                    try self.recreateContext()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // 构建完整 prompt（这部分不需要 GPU，可以在当前线程执行）
        let fullPrompt = buildPrompt(from: messages)
        
        // 分词和评估 prompt 在 GPU 队列上执行
        let promptTokens = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[llama_token], Error>) in
            gpuQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ModelError.modelNotLoaded)
                    return
                }
                
                do {
                    // 分词
                    let tokens = try self.tokenize(fullPrompt)
                    
                    // 评估 prompt
                    try self.evaluatePrompt(tokens)
                    
                    continuation.resume(returning: tokens)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // 流式生成（从 prompt 评估后的状态开始）
        // 这个操作会在 GPU 队列上执行，不会阻塞主线程
        return try await generateTokens(
            promptTokenCount: promptTokens.count,
            maxTokens: config.maxTokens,
            onToken: onToken
        )
    }

    /// 生成响应（非流式）
    /// - Parameter messages: 消息历史
    /// - Returns: 完整响应文本
    func generate(messages: [Message]) async throws -> String {
        return try await generate(messages: messages, onToken: { _ in })
    }
    
    /// 生成响应（异步版本）
    /// - Parameter messages: 消息历史
    /// - Returns: 完整响应文本
    /// - Note: 此方法直接调用 generate，不切换线程。
    ///   Metal GPU 操作必须在主线程或专门的串行队列上执行，不能使用 Task.detached。
    ///   调用者应使用普通的 Task 而不是 Task.detached 来调用此方法。
    func generateAsync(messages: [Message]) async throws -> String {
        // 直接调用 generate，不切换线程
        // 注意：调用者应确保在主线程或专门的队列上调用此方法
        // 不能使用 Task.detached，因为 Metal 不能在任意后台线程上执行
        return try await generate(messages: messages)
    }
    
    /// 检查模型是否已加载
    var isLoaded: Bool {
        return isModelLoaded
    }
    
    // MARK: - Private Methods
    
    /// 确保模型已加载
    private func ensureModelLoaded() throws {
        guard !isModelLoaded else { return }
        
        // 优先在 SelfAi 目录中查找，其次在 Bundle 根目录查找，兼容「资源被扁平化」的情况
        let bundle = Bundle.main
        let candidates: [String?] = [
            bundle.path(forResource: config.modelName, ofType: "gguf", inDirectory: "SelfAi"),
            bundle.path(forResource: config.modelName, ofType: "gguf")
        ]
        
        guard let path = candidates.compactMap({ $0 }).first else {
            throw ModelError.modelFileNotFound
        }
        
        // 加载模型
        var modelParams = llama_model_default_params()
        // 设置 GPU 层数，提升推理性能（如果设备支持 Metal GPU 加速）
        modelParams.n_gpu_layers = config.nGpuLayers
        guard let loadedModel = llama_model_load_from_file(path, modelParams) else {
            throw ModelError.failedToLoadModel
        }
        
        // 创建上下文
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = config.contextSize
        contextParams.n_batch = config.batchSize
        
        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            throw ModelError.failedToCreateContext
        }
        
        // 保存引用
        self.model = loadedModel
        self.context = loadedContext
        self.vocab = llama_model_get_vocab(loadedModel)
        self.isModelLoaded = true
    }
    
    /// 重新创建上下文
    private func recreateContext() throws {
        guard let model = model else {
            throw ModelError.modelNotLoaded
        }
        
        // 释放旧上下文
        if let oldContext = context {
            llama_free(oldContext)
        }
        
        // 创建新上下文
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = config.contextSize
        contextParams.n_batch = config.batchSize
        
        guard let newContext = llama_init_from_model(model, contextParams) else {
            throw ModelError.failedToCreateContext
        }
        
        self.context = newContext
    }
    
    /// 构建完整 prompt
    private func buildPrompt(from messages: [Message]) -> String {
        var prompt = ""
        
        // 添加系统消息
        prompt += "<|im_start|>system\n\(config.systemPrompt)<|im_end|>\n"
        
        // 添加对话历史
        for message in messages {
            let roleTag: String
            switch message.role {
            case .user:
                roleTag = "user"
            case .assistant:
                roleTag = "assistant"
            case .system:
                continue  // 系统消息已在上面添加
            }
            prompt += "<|im_start|>\(roleTag)\n\(message.content)<|im_end|>\n"
        }
        
        // 添加助手开始标记
        prompt += "<|im_start|>assistant\n"
        
        return prompt
    }
    
    /// 分词
    private func tokenize(_ text: String) throws -> [llama_token] {
        guard let vocab = vocab else {
            throw ModelError.modelNotLoaded
        }
        
        let utf8Count = text.utf8.count
        let maxTokenCount = utf8Count + 1
        var tokens = [llama_token](repeating: 0, count: maxTokenCount)
        
        let tokenCount = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            &tokens,
            Int32(maxTokenCount),
            true,  // add BOS
            true   // special tokens
        )
        
        guard tokenCount > 0 else {
            throw ModelError.tokenizationFailed
        }
        
        return Array(tokens.prefix(Int(tokenCount)))
    }
    
    /// 评估 prompt
    private func evaluatePrompt(_ tokens: [llama_token]) throws {
        guard let context = context else {
            throw ModelError.modelNotLoaded
        }
        
        // 确保 batch 大小足够容纳所有 tokens，但不超过配置的最大值
        let batchSize = min(Int(config.batchSize), tokens.count)
        guard batchSize > 0 else {
            throw ModelError.tokenizationFailed
        }
        
        // 如果 tokens 数量超过 batch 大小，需要分批处理
        if tokens.count > batchSize {
            // 分批处理：先处理前面的完整批次（不需要 logits）
            var processedCount = 0
            let fullBatches = tokens.count / batchSize
            
            // 处理完整的批次
            for _ in 0..<fullBatches {
                var batch = llama_batch_init(Int32(batchSize), 0, 1)
                defer { llama_batch_free(batch) }
                
                batch.n_tokens = Int32(batchSize)
                for i in 0..<batchSize {
                    let idx = Int(i)
                    let tokenIdx = processedCount + idx
                    batch.token[idx] = tokens[tokenIdx]
                    batch.pos[idx] = Int32(tokenIdx)
                    batch.n_seq_id[idx] = 1
                    
                    // 安全地设置 seq_id
                    if let seq_ids = batch.seq_id {
                        let seq_id_ptr = seq_ids.advanced(by: idx)
                        if let seq_id = seq_id_ptr.pointee {
                            seq_id.withMemoryRebound(to: Int32.self, capacity: 1) { seqIdArray in
                                seqIdArray[0] = 0
                            }
                        }
                    }
                    
                    // 这批 tokens 都不需要 logits
                    batch.logits[idx] = 0
                }
                
                // 评估这一批
                guard llama_decode(context, batch) == 0 else {
                    throw ModelError.decodeFailed
                }
                
                processedCount += batchSize
            }
            
            // 处理最后一批剩余的 tokens（最后一个 token 需要 logits）
            let remainingCount = tokens.count - processedCount
            if remainingCount > 0 {
                var finalBatch = llama_batch_init(Int32(remainingCount), 0, 1)
                defer { llama_batch_free(finalBatch) }
                
                finalBatch.n_tokens = Int32(remainingCount)
                for i in 0..<remainingCount {
                    let idx = Int(i)
                    let tokenIdx = processedCount + idx
                    finalBatch.token[idx] = tokens[tokenIdx]
                    finalBatch.pos[idx] = Int32(tokenIdx)
                    finalBatch.n_seq_id[idx] = 1
                    
                    // 安全地设置 seq_id
                    if let seq_ids = finalBatch.seq_id {
                        let seq_id_ptr = seq_ids.advanced(by: idx)
                        if let seq_id = seq_id_ptr.pointee {
                            seq_id.withMemoryRebound(to: Int32.self, capacity: 1) { seqIdArray in
                                seqIdArray[0] = 0
                            }
                        }
                    }
                    
                    // 只有最后一个 token 需要 logits
                    finalBatch.logits[idx] = (idx == remainingCount - 1) ? 1 : 0
                }
                
                guard llama_decode(context, finalBatch) == 0 else {
                    throw ModelError.decodeFailed
                }
            }
        } else {
            // tokens 数量在 batch 大小内，一次性处理
            var batch = llama_batch_init(Int32(batchSize), 0, 1)
            defer { llama_batch_free(batch) }
            
            batch.n_tokens = Int32(tokens.count)
            for i in 0..<tokens.count {
                let idx = Int(i)
                batch.token[idx] = tokens[idx]
                batch.pos[idx] = Int32(i)
                batch.n_seq_id[idx] = 1
                
                // 安全地设置 seq_id
                if let seq_ids = batch.seq_id {
                    let seq_id_ptr = seq_ids.advanced(by: idx)
                    if let seq_id = seq_id_ptr.pointee {
                        seq_id.withMemoryRebound(to: Int32.self, capacity: 1) { seqIdArray in
                            seqIdArray[0] = 0
                        }
                    }
                }
                
                // 只有最后一个 token 需要计算 logits
                batch.logits[idx] = (i == tokens.count - 1) ? 1 : 0
            }
            
            // 评估
            guard llama_decode(context, batch) == 0 else {
                throw ModelError.decodeFailed
            }
        }
    }
    
    /// 生成 tokens（流式）
    /// 注意：所有 GPU 操作都在专门的 gpuQueue 上执行，避免阻塞主线程
    private func generateTokens(promptTokenCount: Int, maxTokens: Int, onToken: @escaping (String) async -> Void) async throws -> String {
        guard let context = context,
              let vocab = vocab else {
            throw ModelError.modelNotLoaded
        }
        
        // 在 GPU 队列上创建和维护 batch
        var batch: llama_batch?
        var n_cur = Int32(promptTokenCount)
        var lastGeneratedTokens: [llama_token] = []
        let maxPenaltyTokens = 10
        
        // 在 GPU 队列上初始化 batch（使用配置的 batchSize）
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            gpuQueue.async {
                batch = llama_batch_init(Int32(self.config.batchSize), 0, 1)
                continuation.resume()
            }
        }
        
        defer {
            if let batch = batch {
                gpuQueue.async {
                    llama_batch_free(batch)
                }
            }
        }
        
        guard var batch = batch else {
            throw ModelError.modelNotLoaded
        }
        
        // 使用指针来确保在闭包中可以修改同一个 batch 对象
        let batchPointer = UnsafeMutablePointer<llama_batch>.allocate(capacity: 1)
        batchPointer.initialize(to: batch)
        defer {
            batchPointer.deinitialize(count: 1)
            batchPointer.deallocate()
        }
        
        var accumulatedResponse = ""
        var stoppedDueToBackground = false  // 标记是否因应用进入后台而停止
        
        for _ in 0..<maxTokens {
            // 检查任务是否已取消
            guard !Task.isCancelled else {
                break
            }
            
            // 检查应用状态，如果不在前台则停止生成
            guard isApplicationActive() else {
                // 应用进入后台，停止生成以避免 GPU 操作错误
                stoppedDueToBackground = true
                break
            }
            
            // 在 GPU 队列上执行解码和采样操作
            // 捕获当前状态值，避免闭包中的值变化
            let currentNCur = n_cur
            let currentPenaltyTokens = lastGeneratedTokens
            
            let (nextToken, tokenText, updatedNCur, updatedPenaltyTokens): (llama_token?, String?, Int32, [llama_token]) = try await withCheckedThrowingContinuation { continuation in
                gpuQueue.async { [weak self] in
                    guard let self = self,
                          let context = self.context,
                          let vocab = self.vocab else {
                        continuation.resume(returning: (nil, nil, currentNCur, currentPenaltyTokens))
                        return
                    }
                    
                    // 通过指针访问 batch
                    let currentBatch = batchPointer.pointee
                    
                    // 获取 logits
                    // 第一次循环：从 prompt 的最后一个 token 获取
                    // 后续循环：从 batch 的最后一个 token 获取（位置 batch.n_tokens - 1，即 0）
                    let logitsIndex: Int32
                    if currentBatch.n_tokens == 0 {
                        // 第一次循环，从 prompt 的最后一个 token 获取
                        // 注意：llama_get_logits_ith 返回的是最后一批 batch 中的 logits
                        // 如果 prompt 的 token 数量超过 batch 大小，需要计算最后一批的最后一个 token 在 batch 中的索引
                        let batchSize = Int32(self.config.batchSize)
                        if promptTokenCount > Int(batchSize) {
                            // prompt 被分批处理，计算最后一批的最后一个 token 在 batch 中的索引
                            let remainingCount = promptTokenCount % Int(batchSize)
                            // 如果余数为 0，说明最后一批正好是完整的 batch，最后一个 token 的索引是 batchSize - 1
                            // 否则，最后一个 token 的索引是 remainingCount - 1
                            logitsIndex = remainingCount == 0 ? (batchSize - 1) : Int32(remainingCount - 1)
                        } else {
                            // prompt 在一个 batch 内，直接使用 promptTokenCount - 1
                            logitsIndex = Int32(promptTokenCount - 1)
                        }
                    } else {
                        // 后续循环，从 batch 的最后一个 token 获取
                        logitsIndex = currentBatch.n_tokens - 1
                    }
                    
                    guard let logits = llama_get_logits_ith(context, logitsIndex) else {
                        continuation.resume(returning: (nil, nil, currentNCur, currentPenaltyTokens))
                        return
                    }
                    
                    // 采样（传入需要惩罚的 token 列表）
                    let vocabSize = llama_vocab_n_tokens(vocab)
                    let sampledToken = self.sampleToken(
                        logits: logits,
                        vocabSize: vocabSize,
                        temperature: self.config.temperature,
                        topP: self.config.topP,
                        penaltyTokens: currentPenaltyTokens,
                        penaltyFactor: 1.1
                    )
                    
                    // 检查结束标记
                    if sampledToken == llama_vocab_eos(vocab) {
                        continuation.resume(returning: (sampledToken, nil, currentNCur, currentPenaltyTokens))
                        return
                    }
                    
                    // 将 token 转换为文本
                    let text = self.tokenToText(sampledToken, vocab: vocab)
                    
                    // 准备下一个 token 的批次（通过指针修改）
                    batchPointer.pointee.n_tokens = 1
                    batchPointer.pointee.token[0] = sampledToken
                    batchPointer.pointee.pos[0] = currentNCur
                    batchPointer.pointee.n_seq_id[0] = 1
                    
                    // 安全地设置 seq_id，添加指针有效性检查
                    // seq_id 是一个指向指针数组的指针，每个元素指向一个序列 ID 数组
                    if let seq_ids = batchPointer.pointee.seq_id {
                        let seq_id_ptr = seq_ids.advanced(by: 0)
                        // 检查指针是否有效（不为 nil）
                        if let seq_id = seq_id_ptr.pointee {
                            // 使用 withMemoryRebound 安全地访问序列 ID 数组（序列 ID 通常是 Int32）
                            seq_id.withMemoryRebound(to: Int32.self, capacity: 1) { seqIdArray in
                                seqIdArray[0] = 0
                            }
                        }
                    }
                    
                    batchPointer.pointee.logits[0] = 1
                    
                    // 在 GPU 队列上执行解码操作（不会阻塞主线程）
                    guard llama_decode(context, batchPointer.pointee) == 0 else {
                        continuation.resume(returning: (nil, nil, currentNCur, currentPenaltyTokens))
                        return
                    }
                    
                    // 更新状态
                    var updatedNCur = currentNCur + 1
                    var updatedPenaltyTokens = currentPenaltyTokens
                    updatedPenaltyTokens.append(sampledToken)
                    if updatedPenaltyTokens.count > maxPenaltyTokens {
                        updatedPenaltyTokens.removeFirst()
                    }
                    
                    continuation.resume(returning: (sampledToken, text, updatedNCur, updatedPenaltyTokens))
                }
            }
            
            // 更新状态
            n_cur = updatedNCur
            lastGeneratedTokens = updatedPenaltyTokens
            
            // 检查是否应该结束
            guard let token = nextToken else {
                break
            }
            
            // 如果有文本输出，通知 UI 更新（在主线程上）
            if let text = tokenText, !text.isEmpty {
                accumulatedResponse += text
                // 在主线程上调用回调，确保 UI 更新
                await onToken(text)
                // 让出执行权，让主线程有机会处理 UI 更新
                await Task.yield()
            }
            
            // 如果遇到结束标记，停止生成
            if token == llama_vocab_eos(vocab) {
                break
            }
        }
        
        // 刷新 UTF-8 累积器
        if let remainingText = utf8Accumulator.flush() {
            accumulatedResponse += remainingText
            await onToken(remainingText)
        }
        
        // 如果因应用进入后台而停止，添加提示文本
        if stoppedDueToBackground {
            let backgroundMessage = "[暂停啦]"
            accumulatedResponse += backgroundMessage
            await onToken(backgroundMessage)
        }
        
        return accumulatedResponse
    }
    
    /// Token 转文本
    private func tokenToText(_ token: llama_token, vocab: OpaquePointer) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = llama_token_to_piece(
            vocab,
            token,
            &buffer,
            Int32(buffer.count),
            0,
            false
        )
        
        guard length > 0 else { return nil }
        
        // 将 CChar 数组转换为 UInt8 数组（UTF-8 字节）
        let actualBytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        
        // 使用 UTF-8 累积器处理多字节字符
        return utf8Accumulator.append(actualBytes)
    }
    
    /// 采样函数：使用 temperature 和 top_p，支持重复惩罚（高性能优化版本）
    /// 使用 top-k 预筛选，只处理前 k 个候选，大幅减少计算量
    private func sampleToken(
        logits: UnsafePointer<Float>,
        vocabSize: Int32,
        temperature: Float,
        topP: Float,
        penaltyTokens: [llama_token] = [],
        penaltyFactor: Float = 1.1
    ) -> llama_token {
        // 使用 top-k 预筛选，只处理前 topK 个候选，大幅减少计算量
        let topK = min(80, Int(vocabSize))
        
        // 将重复惩罚 token 转换为 Set，提升查找效率（O(1) 查找）
        let penaltySet = Set(penaltyTokens)
        
        // 第一步：快速找到原始 logit 值最高的 top-k 候选
        // 使用 Swift 的高效排序算法，只取前 k 个
        var rawCandidates: [(token: llama_token, rawLogit: Float)] = []
        rawCandidates.reserveCapacity(Int(vocabSize))
        
        for i in 0..<Int(vocabSize) {
            rawCandidates.append((token: llama_token(i), rawLogit: logits[i]))
        }
        
        // 使用部分排序：只排序到第 k 个元素
        // Swift 的排序算法已经优化，对于部分排序场景性能很好
        rawCandidates.sort { $0.rawLogit > $1.rawLogit }
        let topRawCandidates = Array(rawCandidates.prefix(topK))
        
        // 第二步：只对 top-k 候选应用 temperature 和重复惩罚
        var candidates: [(token: llama_token, logit: Float)] = []
        candidates.reserveCapacity(topK)
        
        for (token, rawLogit) in topRawCandidates {
            var logit = rawLogit
            
            // 应用 temperature
            logit /= temperature
            
            // 重复惩罚
            if penaltySet.contains(token) {
                logit /= penaltyFactor
            }
            
            candidates.append((token: token, logit: logit))
        }
        
        // 重新排序（因为应用了惩罚后顺序可能改变）
        candidates.sort { $0.logit > $1.logit }
        
        // 第三步：计算 exp(logit) - 只对 top-k 计算，而不是全部
        var expLogits: [Float] = []
        expLogits.reserveCapacity(topK)
        for candidate in candidates {
            expLogits.append(expf(candidate.logit))
        }
        
        // 第四步：找到 top_p 的截止点（nucleus sampling）
        let totalSum = expLogits.reduce(0, +)
        var cumulativeProb: Float = 0.0
        var nucleusK = topK
        
        for (index, expLogit) in expLogits.enumerated() {
            cumulativeProb += expLogit / totalSum
            if cumulativeProb >= topP {
                nucleusK = index + 1
                break
            }
        }
        
        // 第五步：从 nucleus 范围内采样
        let nucleusSum = expLogits.prefix(nucleusK).reduce(0, +)
        let random = Float.random(in: 0..<1.0) * nucleusSum
        var cumulative: Float = 0.0
        
        for i in 0..<nucleusK {
            cumulative += expLogits[i]
            if cumulative >= random {
                return candidates[i].token
            }
        }
        
        // 如果采样失败，返回第一个（概率最高的）
        return candidates[0].token
    }
    
    /// 模拟器环境下的 Mock 响应（流式），不依赖真实模型，方便在模拟器中调试 UI
    private func mockResponseStreaming(for messages: [Message], onToken: @escaping (String) async -> Void) async throws -> String {
        // 取最后一条用户消息作为"提问"
        let lastUserMessage = messages.last { $0.role == .user }?.content ?? ""
        
        var fullText = "（模拟器环境 · Mock AI 回复）\n"
        if lastUserMessage.isEmpty {
            fullText += "当前在 iOS 模拟器中运行，为了方便开发体验，这里返回的是本地 mock 文本，而不是实际的大模型推理结果。你可以在真机上获得真实的 AI 陪伴对话。"
        } else {
            fullText += """
当前在 iOS 模拟器中运行，为了避免加载本地大模型导致的性能 / 二进制问题，这里返回的是 mock 文本。

你刚才说的是：
「\(lastUserMessage)」

如果你想体验真实的 AI 陪伴效果，请在真机上运行应用。
"""
        }
        
        // 流式输出：逐字符发送，模拟真实的流式效果
        var accumulated = ""
        for char in fullText {
            let charString = String(char)
            accumulated += charString
            await onToken(charString)
            // 添加小延迟以模拟真实生成速度
            try await Task.sleep(nanoseconds: 20_000_000) // 每个字符延迟 20ms
        }
        
        return accumulated
    }
    
    /// 检查应用是否在前台
    private func isApplicationActive() -> Bool {
        #if os(iOS)
        return UIApplication.shared.applicationState == .active
        #elseif os(macOS)
        return NSApplication.shared.isActive
        #else
        return true  // 其他平台默认返回 true
        #endif
    }
    
    /// 停止生成（用于取消正在进行的生成任务）
    func stopGenerating() {
        isGenerating = false
    }
    
    /// 检查是否正在生成
    var generating: Bool {
        return isGenerating
    }
    
    /// 清理资源
    private func cleanup() {
        // 模拟器环境下没有初始化 llama 后端，直接返回
        if isSimulator {
            return
        }
        
        // 如果正在生成，先停止
        isGenerating = false
        
        // 注意：在 deinit 中不能进行 GPU 同步操作，因为应用可能已经进入后台
        // 直接释放资源，让系统自动清理 GPU 资源
        
        // 释放上下文
        if let context = context {
            // 直接释放，不尝试同步 GPU（避免后台执行错误）
            llama_free(context)
            self.context = nil
        }
        // 释放模型
        if let model = model {
            llama_model_free(model)
            self.model = nil
        }
        // 清理后端（在所有资源释放后）
        llama_backend_free()
        isModelLoaded = false
    }
}

// MARK: - Model Errors

enum ModelError: LocalizedError {
    case modelFileNotFound
    case failedToLoadModel
    case failedToCreateContext
    case modelNotLoaded
    case tokenizationFailed
    case decodeFailed
    case applicationInBackground
    
    var errorDescription: String? {
        switch self {
        case .modelFileNotFound:
            return "找不到模型文件"
        case .failedToLoadModel:
            return "无法加载模型"
        case .failedToCreateContext:
            return "无法创建上下文"
        case .modelNotLoaded:
            return "模型未加载"
        case .tokenizationFailed:
            return "分词失败"
        case .decodeFailed:
            return "解码失败"
        case .applicationInBackground:
            return "应用已进入后台，无法继续生成"
        }
    }
}

