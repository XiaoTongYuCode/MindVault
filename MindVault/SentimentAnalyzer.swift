import Foundation

actor SentimentAnalyzer {
    private let model: LlamaModel
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
            {"score": 0.8, "summary": "Feeling great today", "tag": "Work"}
            
            Rules:
            1. score is a number from -1.0 to 1.0: 1.0 most positive, -1.0 most negative, 0.0 neutral
            2. summary is a brief English description of mood, guide user to think positively
            3. score and summary must be consistent: positive mood uses positive number, negative mood uses negative number
            4. tag must be one of: Study, Work, Family, Health, Travel, Hobby, Relationship, Reflection, Other
            5. Choose the most appropriate tag based on diary content, if none fits then choose "Other"
            6. Output JSON only, no code block markers, no explanatory text
            
            Examples:
            Input: "Got paid today, very happy"
            Output: {"score": 0.7, "summary": "Getting paid brings joy, keep up the good mood", "tag": "Work"}
            
            Input: "Work pressure is high, very tired"
            Output: {"score": -0.5, "summary": "Work pressure needs adjustment, try to relax and rest", "tag": "Work"}
            
            Input: "Watched a movie with my girlfriend today, very happy"
            Output: {"score": 0.8, "summary": "Spending quality time with loved one, cherish the moment", "tag": "Relationship"}
            
            Input: "Learned new programming knowledge today"
            Output: {"score": 0.6, "summary": "Learning brings growth, keep it up", "tag": "Study"}
            """
        } else {
            prompt = """
            分析日记情感和标签，输出JSON格式。
            
            输出格式（必须严格遵循，只输出JSON，不要其他文字）：
            {"score": 0.8, "summary": "今天心情很好", "tag": "工作"}
            
            规则：
            1. score是-1.0到1.0的数字：1.0最积极，-1.0最消极，0.0中性
            2. summary是简短中文，描述心情，引导用户积极思考
            3. score和summary必须一致：积极心情用正数，消极心情用负数
            4. tag必须是以下之一：学习、工作、家庭、健康、旅行、爱好、情感、思考、其他
            5. 根据日记内容选择最合适的标签，如果都不合适则选择"其他"
            6. 只输出JSON，不要代码块标记、不要解释文字
            
            示例：
            输入："今天发工资了，很开心"
            输出：{"score": 0.7, "summary": "发工资带来喜悦，继续保持好心情", "tag": "工作"}
            
            输入："工作压力很大，很累"
            输出：{"score": -0.5, "summary": "工作压力需要调节，可以尝试放松和休息", "tag": "工作"}
            
            输入："今天和女朋友一起看电影，很幸福"
            输出：{"score": 0.8, "summary": "与爱人共度美好时光，珍惜当下", "tag": "情感"}
            
            输入："今天学习了新的编程知识"
            输出：{"score": 0.6, "summary": "学习带来成长，继续保持", "tag": "学习"}
            """
        }
        
        let config = ModelConfig(
            temperature: 0.2,
            topP: 0.9,
            maxTokens: 256,
            contextSize: 2048,
            batchSize: 512,
            systemPrompt: prompt
        )
        model = LlamaModel(config: config)
    }

    /// 在后台预热模型，避免首次分析时卡顿
    /// 可以在 App 启动后尽早调用
    func warmUp() async {
        // 只触发底层模型加载，不进行完整推理，尽量减小预热时的算力与耗时
        model.warmUp()
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
        var clampedScore = max(-1.0, min(1.0, payload.score))
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
