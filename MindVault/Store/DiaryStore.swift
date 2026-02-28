import SwiftUI
import CoreData
import Combine

@MainActor
final class DiaryStore: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var aiGreeting: String = ""

    private let context: NSManagedObjectContext
    private var observer: NSObjectProtocol?
    private let analyzer = SentimentAnalyzer()
    private let greetingKey = "com.mindvault.ai_greeting"
    private let greetingEntriesHashKey = "com.mindvault.greeting_entries_hash"
    private var isGeneratingGreeting = false

    init(context: NSManagedObjectContext) {
        self.context = context
        refresh()
        // 应用启动时只加载缓存的问候语
        loadCachedGreeting()
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
            // 日记变化时触发问候语生成
            self?.checkAndGenerateGreeting()
        }
    }

    /// 在应用启动后预热情感分析模型，避免第一次保存日记时长时间等待
    /// 同时检查并重新分析之前分析失败的日记
    /// 此方法立即返回，所有工作都在后台异步执行，不会阻塞主线程
    func warmUpSentimentAnalyzer() {
        // 在后台异步执行预热和重新分析，不阻塞主线程
        Task { [weak self] in
            guard let self = self else { return }
            
            // 预热情感分析模型
            await self.analyzer.warmUp()
            
            // 查询所有分析失败的日记（sentimentLabel == "mood.neutral" 且 sentimentSummary == "entry.analysis.failed"）
            let request = DiaryEntryEntity.fetchRequestAll()
            request.predicate = NSPredicate(
                format: "sentimentLabel == %@ AND sentimentSummary == %@",
                "mood.neutral",
                "entry.analysis.failed"
            )
            
            let failedEntries: [DiaryEntryEntity]
            do {
                failedEntries = try self.context.fetch(request)
            } catch {
                print("❌ 查询分析失败的日记时出错：\(error.localizedDescription)")
                return
            }
            
            // 如果有失败的日记，在后台重新分析
            if !failedEntries.isEmpty {
                print("📝 发现 \(failedEntries.count) 条分析失败的日记，开始重新分析...")
                for entity in failedEntries {
                    // reanalyzeEntry 内部使用 Task 异步执行，不需要 await
                    self.reanalyzeEntry(entity: entity)
                }
            }
        }
    }
    
    /// 重新分析指定的日记条目
    private func reanalyzeEntry(entity: DiaryEntryEntity) {
        let entryID = entity.id
        let content = entity.content
        
        // 标记为正在分析
        entity.isAnalyzing = true
        saveContext()
        
        // 在后台异步执行情感分析，不阻塞主线程
        // 使用 Task 来启动异步工作，类似于 addEntry 的实现方式
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // 重新执行情感分析
                let result = try await self.analyzer.analyze(content: content)
                
                // 分析完成后，在主线程更新 Core Data（DiaryStore 是 @MainActor）
                if let target = self.fetchEntity(id: entryID) {
                    target.sentimentScore = NSNumber(value: result.sentiment.score)
                    target.sentimentLabel = result.sentiment.label
                    target.sentimentEmoji = result.sentiment.emoji
                    target.sentimentSummary = result.sentiment.summary
                    target.tag = result.tag?.rawValue
                    target.isAnalyzing = false
                    target.updatedAt = Date()
                    self.saveContext()
                    print("✅ 重新分析成功，日记ID：\(entryID.uuidString)")
                }
            } catch {
                // 重新分析失败，保持失败状态
                print("❌ 重新分析失败，日记ID：\(entryID.uuidString)")
                print("   错误类型：\(type(of: error))")
                print("   错误描述：\(error.localizedDescription)")
                
                // 更新分析状态为失败
                if let target = self.fetchEntity(id: entryID) {
                    target.isAnalyzing = false
                    target.updatedAt = Date()
                    self.saveContext()
                }
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func addEntry(title: String, content: String, images: [Data] = []) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (trimmed.count > 20 ? String(trimmed.prefix(20)) + "..." : trimmed)
            : title
        let now = Date()

        // 先创建 UUID，然后创建实体并赋值
        let entryID = UUID()
        let entity = DiaryEntryEntity(context: context)
        entity.id = entryID
        entity.title = resolvedTitle
        entity.content = content
        entity.createdAt = now
        entity.updatedAt = now
        entity.isAnalyzing = true

        // 保存圖片
        for (index, data) in images.enumerated() {
            let imageEntity = DiaryImageEntity(context: context)
            imageEntity.id = UUID()
            imageEntity.imageData = data
            imageEntity.orderIndex = Int16(index)
            imageEntity.entry = entity
        }

        saveContext()

        // 在后台异步执行情感分析和标签分析，不阻塞主线程
        // 由于 SentimentAnalyzer 是 actor，analyze 方法内部已经使用异步 generateAsync，
        // 所以这里可以直接使用 Task，不需要 Task.detached
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // SentimentAnalyzer.analyze 内部已经使用异步 generateAsync，在后台线程执行
                let result = try await self.analyzer.analyze(content: content)
                
                // 分析完成后，在主线程更新 Core Data（DiaryStore 是 @MainActor）
                if let target = self.fetchEntity(id: entryID) {
                    target.sentimentScore = NSNumber(value: result.sentiment.score)
                    target.sentimentLabel = result.sentiment.label
                    target.sentimentEmoji = result.sentiment.emoji
                    target.sentimentSummary = result.sentiment.summary
                    target.tag = result.tag?.rawValue
                    target.isAnalyzing = false
                    target.updatedAt = Date()
                    self.saveContext()
                }
            } catch {
                // 这里集中处理情感分析错误，方便调试
                print("❌ 情感分析失败，日记ID：\(entryID.uuidString)")
                print("   错误类型：\(type(of: error))")
                print("   错误描述：\(error.localizedDescription)")
                if let sentimentError = error as? SentimentError {
                    print("   详细错误：\(sentimentError.errorDescription ?? "无")")
                }

                // 分析失败时，在主线程更新状态
                if let target = self.fetchEntity(id: entryID) {
                    // 分析失败时也写入一个「失败」情绪，避免前端一直认为未分析
                    target.sentimentScore = 0
                    target.sentimentLabel = "mood.neutral"  // 使用本地化键
                    target.sentimentEmoji = "😐"
                    target.sentimentSummary = "entry.analysis.failed"  // 使用本地化键
                    target.isAnalyzing = false
                    target.updatedAt = Date()
                    self.saveContext()
                }
            }
        }
        
        // 日记添加后，触发问候语生成
        checkAndGenerateGreeting()
    }

    func deleteEntry(_ entry: DiaryEntry) {
        if let target = fetchEntity(id: entry.id) {
            context.delete(target)
            saveContext()
        }
        // 删除日记后，触发问候语生成
        checkAndGenerateGreeting()
    }

    private func refresh() {
        let request = DiaryEntryEntity.fetchRequestAll()
        do {
            let results = try context.fetch(request)
            entries = results.map { $0.toDiaryEntry() }
        } catch {
            entries = []
        }
    }
    
    /// 加载缓存的问候语
    private func loadCachedGreeting() {
        if let cached = UserDefaults.standard.string(forKey: greetingKey), !cached.isEmpty {
            aiGreeting = cached
        } else {
            // 如果没有缓存的问候语，使用默认值
            let savedLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "zh-Hans"
            aiGreeting = savedLanguage == "en" 
                ? "Welcome! Start your first diary entry to begin your journey."
                : "Hi！空空的岛上还只有我一个，等你来留下第一行足迹。"
        }
    }
    
    /// 计算最近5条日记的哈希值，用于判断是否需要重新生成问候语
    private func entriesHash() -> String {
        let recentEntries = Array(entries.prefix(5))
        let content = recentEntries.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }.joined(separator: "|")
        return String(content.hashValue)
    }
    
    /// 检查并生成问候语（如果日记有变化）
    private func checkAndGenerateGreeting() {
        // 如果正在生成，跳过
        guard !isGeneratingGreeting else { return }
        
        // 如果没有日记，使用默认问候语
        guard !entries.isEmpty else {
            let savedLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "zh-Hans"
            aiGreeting = savedLanguage == "en" 
                ? "Welcome! Start your first diary entry to begin your journey."
                : "Hi！空空的岛上还只有我一个，等你来留下第一行足迹。"
            return
        }
        
        // 计算当前日记的哈希值
        let currentHash = entriesHash()
        let cachedHash = UserDefaults.standard.string(forKey: greetingEntriesHashKey)
        
        // 如果哈希值相同，说明日记没有变化，直接使用缓存的问候语
        if currentHash == cachedHash {
            return
        }
        
        // 日记有变化，生成新的问候语
        generateGreeting()
    }
    
    /// 生成AI问候语
    private func generateGreeting() {
        guard !isGeneratingGreeting else { return }
        guard !entries.isEmpty else { return }
        
        isGeneratingGreeting = true
        
        // 获取最近5条日记
        let recentEntries = Array(entries.prefix(5))
        
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let greeting = try await self.analyzer.generateGreeting(from: recentEntries)
                
                // 检查问候语是否包含"[暂停啦]"，如果包含则视为分析失败
                if greeting.contains("[暂停啦]") {
                    print("⚠️ 生成的问候语包含[暂停啦]，视为分析失败，保持原有问候语")
                    await MainActor.run {
                        self.isGeneratingGreeting = false
                    }
                    return
                }
                
                // 在主线程更新UI和缓存
                await MainActor.run {
                    self.aiGreeting = greeting
                    UserDefaults.standard.set(greeting, forKey: self.greetingKey)
                    UserDefaults.standard.set(self.entriesHash(), forKey: self.greetingEntriesHashKey)
                    self.isGeneratingGreeting = false
                }
            } catch {
                print("❌ 生成问候语失败：\(error.localizedDescription)")
                // 生成失败时，保持原有问候语或使用默认值
                await MainActor.run {
                    self.isGeneratingGreeting = false
                }
            }
        }
    }

    private func fetchEntity(id: UUID) -> DiaryEntryEntity? {
        let request = DiaryEntryEntity.fetchRequestAll()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }

    // MARK: - 草稿功能
    
    private let draftTitleKey = "com.mindvault.draft.title"
    private let draftContentKey = "com.mindvault.draft.content"
    private let draftImagesKey = "com.mindvault.draft.images"
    
    /// 保存草稿
    func saveDraft(title: String, content: String, images: [Data]) {
        UserDefaults.standard.set(title, forKey: draftTitleKey)
        UserDefaults.standard.set(content, forKey: draftContentKey)
        UserDefaults.standard.set(images, forKey: draftImagesKey)
    }
    
    /// 加载草稿
    func loadDraft() -> (title: String, content: String, images: [Data])? {
        guard let title = UserDefaults.standard.string(forKey: draftTitleKey),
              let content = UserDefaults.standard.string(forKey: draftContentKey) else {
            return nil
        }
        let images = UserDefaults.standard.array(forKey: draftImagesKey) as? [Data] ?? []
        return (title: title, content: content, images: images)
    }
    
    /// 清除草稿
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftTitleKey)
        UserDefaults.standard.removeObject(forKey: draftContentKey)
        UserDefaults.standard.removeObject(forKey: draftImagesKey)
    }

}
