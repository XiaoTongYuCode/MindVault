import Foundation

actor SentimentAnalyzer {
    private let model: LlamaModel
    private let greetingModel: LlamaModel
    private let isEnglish: Bool

    init() {
        // 获取当前语言环境（直接从 UserDefaults 读取，避免 @MainActor 问题）
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language")
        if let savedLanguage = savedLanguage, savedLanguage == "en" {
            isEnglish = true
        } else if let savedLanguage = savedLanguage, savedLanguage == "zh-Hans" {
            isEnglish = false
        } else {
            // 如果没有保存的设置，使用系统语言
            let systemLanguage = Locale.preferredLanguages.first ?? "en"
            isEnglish = !systemLanguage.hasPrefix("zh")
        }
        
        let prompt: String
        if isEnglish {
            prompt = """
            Analyze diary sentiment and tag, output JSON format.
            
            Output format (must strictly follow, output JSON only, no other text):
            {"score": 0.8, "sentimentType": "positive", "summary": "Feeling great today", "tag": "Work"}
            
            JSON Schema:
            {
              "score": number (0.0-1.0),
              "sentimentType": "positive" | "negative",
              "summary": string,
              "tag": "Study" | "Work" | "Family" | "Health" | "Travel" | "Hobby" | "Relationship" | "Reflection" | "Other"
            }
            
            Rules:
            1. score: 0.0 = neutral/weak emotion, 1.0 = very strong emotion
            2. sentimentType: "positive" for happy/good feelings, "negative" for sad/bad feelings
            3. summary: brief English description, guide user to think positively
            4. score and sentimentType must be consistent
            5. tag: choose the most appropriate one, or "Other" if none fits
            6. Output JSON only, no code block markers, no explanatory text
            
            Examples:
            Input: "Got paid today, very happy"
            Output: {"score": 0.7, "sentimentType": "positive", "summary": "Getting paid brings joy, keep up the good mood", "tag": "Work"}
            
            Input: "Work pressure is high, very tired"
            Output: {"score": 0.5, "sentimentType": "negative", "summary": "Work pressure needs adjustment, try to relax and rest", "tag": "Work"}
            
            Input: "Watched a movie with my girlfriend today, very happy"
            Output: {"score": 0.8, "sentimentType": "positive", "summary": "Spending quality time with loved one, cherish the moment", "tag": "Relationship"}
            
            Input: "Learned new programming knowledge today"
            Output: {"score": 0.6, "sentimentType": "positive", "summary": "Learning brings growth, keep it up", "tag": "Study"}
            
            Input: "Feeling okay today, nothing special"
            Output: {"score": 0.2, "sentimentType": "positive", "summary": "A peaceful day, appreciate the calm moments", "tag": "Other"}
            """
        } else {
            prompt = """
            你是一位安静的情感朋友，你负责倾听用户的心声，理解他们的情感，给予他们支持和鼓励。
            主要任务：分析日记情感和标签，输出JSON格式。
            
            输出格式（必须严格遵循，只输出JSON，不要其他文字）：
            {"score": 0.8, "sentimentType": "正面情绪", "summary": "今天心情很好", "tag": "工作"}
            
            JSON结构定义：
            {
              "score": 数字 (0.0-1.0),
              "sentimentType": "正面情绪" | "负面情绪",
              "summary": 字符串,
              "tag": "学习" | "工作" | "家庭" | "健康" | "旅行" | "爱好" | "情感" | "思考" | "其他"
            }
            
            规则：
            1. score：0.0表示中性/情绪很弱，1.0表示情绪非常强烈
            2. sentimentType："正面情绪"表示开心/好的感受，"负面情绪"表示难过/不好的感受
            3. summary：简短中文，描述心情，引导用户积极思考
            4. score和sentimentType必须一致
            5. tag：根据日记内容选择最合适的标签，如果都不合适则选择"其他"
            6. 只输出JSON，不要代码块标记、不要解释文字
            
            示例：
            输入："今天发工资了，很开心"
            输出：{"score": 0.7, "sentimentType": "正面情绪", "summary": "发工资带来喜悦，继续保持好心情", "tag": "工作"}
            
            输入："工作压力很大，很累"
            输出：{"score": 0.5, "sentimentType": "负面情绪", "summary": "工作压力需要调节，可以尝试放松和休息，要不听会儿最喜欢的歌？", "tag": "工作"}
            
            输入："今天和女朋友一起看电影，很幸福"
            输出：{"score": 0.8, "sentimentType": "正面情绪", "summary": "与爱人共度美好时光，牢记在这里留下的美好回忆", "tag": "情感"}
            
            输入："今天学习了新的编程知识"
            输出：{"score": 0.6, "sentimentType": "正面情绪", "summary": "学习带来成长，继续保持，你真棒！", "tag": "学习"}
            
            输入："今天心情一般，没什么特别的"
            输出：{"score": 0.2, "sentimentType": "正面情绪", "summary": "平静的一天，请享受这份宁静", "tag": "其他"}
            """
        }
        
        // 减小 batchSize 和 contextSize 以降低内存使用，避免内存不足导致崩溃
        let config = ModelConfig(
            temperature: 0.2,
            topP: 0.9,
            maxTokens: 256,
            contextSize: 1024,  // 从 2048 减小到 1024，降低内存占用
            batchSize: 256,      // 从 512 减小到 256，降低内存占用
            systemPrompt: prompt
        )
        model = LlamaModel(config: config)
        
        // 为问候语生成创建单独的模型配置
        // 获取当前日期时间
        let dateFormatter = DateFormatter()
        if isEnglish {
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        } else {
            dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "zh_CN")
        }
        let currentDateTime = dateFormatter.string(from: Date())
        
        let greetingPrompt: String
        if isEnglish {
            greetingPrompt = """
            You are a thoughtful and empathetic AI assistant. Based on the user's recent diary entries, generate a warm, personalized greeting that shows understanding of their current state of mind and life situation.
            
            Current date and time: \(currentDateTime)
            
            Rules:
            1. Read and understand the user's recent diary entries
            2. Identify their emotional patterns, concerns, and life themes
            3. Generate a brief, warm greeting (1 sentences, max 30 words)
            4. Be empathetic and supportive
            5. Reference their recent experiences naturally if appropriate
            6. Consider the current date and time when generating the greeting
            7. Output only the greeting text, no explanations or additional text
            
            Examples:
            If user has been stressed about work: "I notice you've been dealing with work pressure lately. Take a moment to breathe and remember that you're doing your best."
            If user has been happy: "It's wonderful to see your positive energy in recent entries. Keep that joy flowing!"
            If user has been reflective: "Your thoughtful reflections show deep self-awareness. Continue exploring your inner world."
            """
        } else {
            greetingPrompt = """
            你是一个体贴且安静的情感朋友，你负责倾听用户的心声，理解他们的情感，给予他们支持和鼓励。
            主要任务：根据用户最近的日记内容，生成一个温暖、个性化的问候语，展现对他们当前心理状态和生活情况的理解。
            
            当前日期时间：\(currentDateTime)
            
            规则：
            1. 阅读并理解用户最近的日记内容
            2. 识别他们的情绪模式、关注点和生活主题
            3. 生成简短、温暖的问候语（1句话，最多30字）
            4. 要富有同理心和支持性
            5. 如果合适，自然地提及他们最近的经历
            6. 生成问候语时考虑当前日期时间
            7. 只输出问候语文本，不要解释或其他文字
            
            示例：
            如果用户最近工作压力大："我注意到你最近在工作上有些压力。深呼吸一下，记住你已经尽力了。要不听会儿最喜欢的歌？"
            如果用户最近很开心："看到你最近的日记中充满正能量，真为你高兴！请继续保持这份快乐！"
            如果用户最近在思考："你的深度思考展现了很好的自我觉察。继续探索你的内心世界吧。我会一直在这里。"
            """
        }
        
        let greetingConfig = ModelConfig(
            temperature: 0.7,  // 稍高的温度，让问候语更自然
            topP: 0.9,
            maxTokens: 128,   // 问候语不需要太长
            contextSize: 2048, // 需要更大的上下文来理解多篇日记
            batchSize: 256,
            systemPrompt: greetingPrompt
        )
        greetingModel = LlamaModel(config: greetingConfig)
    }

    /// 在后台预热模型，避免首次分析时卡顿
    /// 可以在 App 启动后尽早调用
    func warmUp() async {
        // 只触发底层模型加载，不进行完整推理，尽量减小预热时的算力与耗时
        model.warmUp()
        greetingModel.warmUp()
    }

    func analyze(content: String) async throws -> (sentiment: DiaryEntry.Sentiment, tag: DiaryTag?) {
        // 使用简洁直接的指令，避免小模型混淆
        let userMessage = isEnglish ? "Analyze this diary entry:\n\(content)" : "分析这段日记：\n\(content)"
        let messages = [Message(role: .user, content: userMessage)]
        // 使用异步版本，在后台线程执行，避免阻塞
        let raw = try await model.generateAsync(messages: messages)
        
        // 记录原始响应，方便调试
        print("🔍 [SentimentAnalyzer] 模型原始响应（前500字符）：\(String(raw))")
        
        let payload = try SentimentAnalyzer.parsePayload(from: raw, rawResponse: raw)
        let sentiment = SentimentAnalyzer.normalize(payload)
        let tag = parseTag(payload.tag)
        return (sentiment, tag)
    }

    private struct SentimentPayload: Decodable {
        let score: Double
        let sentimentType: String
        let summary: String
        let tag: String?
    }

    private static func parsePayload(from text: String, rawResponse: String) throws -> SentimentPayload {
        // 优先处理模型可能返回的 ```json ... ``` 或 ``` ... ``` 代码块
        let extracted: String
        if let codeBlock = extractJSONCodeBlock(from: text) {
            extracted = codeBlock
            print("🔍 [SentimentAnalyzer] 从代码块中提取 JSON")
        } else {
            do {
                extracted = try extractJSON(from: text)
                print("🔍 [SentimentAnalyzer] 从文本中提取 JSON")
            } catch {
                print("❌ [SentimentAnalyzer] JSON 提取失败")
                print("   原始文本长度：\(text.count)")
                print("   原始文本内容：\(text)")
                throw SentimentError.invalidResponse(rawResponse: rawResponse)
            }
        }

        let json = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 [SentimentAnalyzer] 提取的 JSON：\(json)")
        
        guard let data = json.data(using: .utf8) else {
            print("❌ [SentimentAnalyzer] JSON 无法转换为 UTF-8 数据")
            throw SentimentError.invalidResponse(rawResponse: rawResponse)
        }
        
        do {
            return try JSONDecoder().decode(SentimentPayload.self, from: data)
        } catch {
            print("❌ [SentimentAnalyzer] JSON 解析失败：\(error)")
            if let decodingError = error as? DecodingError {
                print("   解码错误详情：\(decodingError)")
            }
            throw SentimentError.invalidResponse(rawResponse: rawResponse)
        }
    }

    /// 从包含 Markdown 代码块的文本中提取 ```json ... ``` 或 ``` ... ``` 中的内容
    private static func extractJSONCodeBlock(from text: String) -> String? {
        // 优先匹配 ```json 代码块
        if let jsonFenceRange = text.range(of: "```json") ?? text.range(of: "```JSON") {
            // 找到语言标记后的第一行换行符
            let searchStart = jsonFenceRange.upperBound
            let newlineIndex = text[searchStart...].firstIndex(of: "\n") ?? searchStart
            let contentStart = text.index(after: newlineIndex)

            guard let endFenceRange = text.range(of: "```", range: contentStart..<text.endIndex) else {
                return nil
            }
            return String(text[contentStart..<endFenceRange.lowerBound])
        }

        // 退化处理：任意 ``` 包裹的代码块
        if let fenceRange = text.range(of: "```") {
            let searchStart = fenceRange.upperBound
            let newlineIndex = text[searchStart...].firstIndex(of: "\n") ?? searchStart
            let contentStart = text.index(after: newlineIndex)

            guard let endFenceRange = text.range(of: "```", range: contentStart..<text.endIndex) else {
                return nil
            }
            return String(text[contentStart..<endFenceRange.lowerBound])
        }

        return nil
    }

    private static func extractJSON(from text: String) throws -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            throw SentimentError.invalidResponse()
        }
        return String(text[start...end])
    }

    private static func normalize(_ payload: SentimentPayload) -> DiaryEntry.Sentiment {
        // 将 0.0-1.0 的 score 和 sentimentType 转换为 -1.0 到 1.0 的 score
        let rawScore = max(0.0, min(1.0, payload.score))
        let sentimentTypeLower = payload.sentimentType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 判断是正面还是负面情绪（支持中英文）
        // 默认假设为正面情绪，如果明确是负面则设为负面
        let isPositive: Bool
        if sentimentTypeLower.contains("negative") || 
           sentimentTypeLower.contains("负面") ||
           sentimentTypeLower == "negative" ||
           sentimentTypeLower == "负面情绪" {
            isPositive = false
        } else {
            // 默认或明确为 positive/正面情绪
            isPositive = true
        }
        
        // 转换为 -1.0 到 1.0 的范围：正面情绪为正数，负面情绪为负数
        let finalScore: Double
        if isPositive {
            finalScore = rawScore  // 正面：0.0 -> 0.0, 1.0 -> 1.0
        } else {
            finalScore = -rawScore  // 负面：0.0 -> 0.0, 1.0 -> -1.0
        }
        
        let clampedScore = max(-1.0, min(1.0, finalScore))
        let summary = payload.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = labelForScore(clampedScore)
        let emoji = emoji(for: label)
        
        return DiaryEntry.Sentiment(
            score: clampedScore,
            label: label,
            emoji: emoji,
            summary: summary.isEmpty ? "情绪分析完成。" : summary
        )
    }

    private static func labelForScore(_ score: Double) -> String {
        // 5个情绪等级：-2, -1, 0, 1, 2
        // 返回本地化键，而不是硬编码的中文
        if score > 0.6 { return "mood.very_positive" }
        if score > 0.2 { return "mood.positive" }
        if score < -0.6 { return "mood.very_negative" }
        if score < -0.2 { return "mood.negative" }
        return "mood.neutral"
    }

    private static func emoji(for label: String) -> String {
        // 支持本地化键和旧的中文标签（向后兼容）
        switch label {
        case "mood.very_positive", "兴奋": return "😄"
        case "mood.positive", "积极": return "😊"
        case "mood.neutral", "中性": return "😐"
        case "mood.negative", "消极": return "😔"
        case "mood.very_negative", "沮丧": return "😢"
        default: return "😐"
        }
    }
    
    private func parseTag(_ tagString: String?) -> DiaryTag? {
        guard let tagString = tagString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !tagString.isEmpty else {
            return nil
        }
        // 根据当前语言环境解析标签
        if isEnglish {
            // 英文环境下，尝试从英文标签解析
            if let tag = DiaryTag.from(englishTag: tagString) {
                return tag
            }
            // 如果英文解析失败，尝试中文标签（向后兼容）
            return DiaryTag.from(chineseTag: tagString)
        } else {
            // 中文环境下，使用中文标签解析
            return DiaryTag.from(chineseTag: tagString)
        }
    }
    
    /// 根据最近的日记生成个性化问候语
    /// - Parameter recentEntries: 最近的日记条目（最多10条）
    /// - Returns: 个性化的问候语
    func generateGreeting(from recentEntries: [DiaryEntry]) async throws -> String {
        guard !recentEntries.isEmpty else {
            // 如果没有日记，返回默认问候语
            return isEnglish ? "Welcome! Start your first diary entry to begin your journey." : "欢迎！写下第一篇日记，开始你的记录之旅。"
        }
        
        // 构建日记内容摘要（最多10条）
        let entriesToAnalyze = Array(recentEntries.prefix(10))
        var diaryContent = ""
        for (index, entry) in entriesToAnalyze.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            let dateStr = dateFormatter.string(from: entry.createdAt)
            diaryContent += "[\(dateStr)] \(entry.content)\n"
        }
        
        let userMessage = isEnglish 
            ? "Based on these recent diary entries, generate a personalized greeting:\n\n\(diaryContent)"
            : "根据以下最近的日记内容，生成一个问候语：\n\n\(diaryContent)"
        
        let messages = [Message(role: .user, content: userMessage)]
        let raw = try await greetingModel.generateAsync(messages: messages)
        
        // 清理输出，移除可能的代码块标记
        var greeting = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除可能的引号
        if greeting.hasPrefix("\"") && greeting.hasSuffix("\"") {
            greeting = String(greeting.dropFirst().dropLast())
        }
        
        // 移除可能的代码块标记
        if greeting.hasPrefix("```") {
            if let endIndex = greeting.range(of: "```", range: greeting.index(after: greeting.startIndex)..<greeting.endIndex)?.upperBound {
                greeting = String(greeting[endIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return greeting.isEmpty 
            ? (isEnglish ? "Welcome back! How are you feeling today?" : "欢迎回来！今天感觉怎么样？")
            : greeting
    }
}

enum SentimentError: LocalizedError {
    case invalidResponse(rawResponse: String? = nil)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "情感分析返回内容无法解析"
        }
    }
}
