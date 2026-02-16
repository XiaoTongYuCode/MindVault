import SwiftUI
import CoreData
import Combine

@MainActor
final class DiaryStore: ObservableObject {
    @Published var entries: [DiaryEntry] = []

    private let context: NSManagedObjectContext
    private var observer: NSObjectProtocol?
    private let analyzer = SentimentAnalyzer()

    init(context: NSManagedObjectContext) {
        self.context = context
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    /// 在应用启动后预热情感分析模型，避免第一次保存日记时长时间等待
    func warmUpSentimentAnalyzer() async {
        await analyzer.warmUp()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func addEntry(title: String, content: String) {
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
    }

    func deleteEntry(_ entry: DiaryEntry) {
        if let target = fetchEntity(id: entry.id) {
            context.delete(target)
            saveContext()
        }
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
    
    /// 保存草稿
    func saveDraft(title: String, content: String) {
        UserDefaults.standard.set(title, forKey: draftTitleKey)
        UserDefaults.standard.set(content, forKey: draftContentKey)
    }
    
    /// 加载草稿
    func loadDraft() -> (title: String, content: String)? {
        guard let title = UserDefaults.standard.string(forKey: draftTitleKey),
              let content = UserDefaults.standard.string(forKey: draftContentKey) else {
            return nil
        }
        return (title: title, content: content)
    }
    
    /// 清除草稿
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftTitleKey)
        UserDefaults.standard.removeObject(forKey: draftContentKey)
    }

}
