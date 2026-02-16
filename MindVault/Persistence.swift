import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "MindVaultModel", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "DiaryEntryEntity"
        entity.managedObjectClassName = NSStringFromClass(DiaryEntryEntity.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false

        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = false

        let content = NSAttributeDescription()
        content.name = "content"
        content.attributeType = .stringAttributeType
        content.isOptional = false

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = false

        let sentimentScore = NSAttributeDescription()
        sentimentScore.name = "sentimentScore"
        sentimentScore.attributeType = .doubleAttributeType
        sentimentScore.isOptional = true

        let sentimentLabel = NSAttributeDescription()
        sentimentLabel.name = "sentimentLabel"
        sentimentLabel.attributeType = .stringAttributeType
        sentimentLabel.isOptional = true

        let sentimentEmoji = NSAttributeDescription()
        sentimentEmoji.name = "sentimentEmoji"
        sentimentEmoji.attributeType = .stringAttributeType
        sentimentEmoji.isOptional = true

        let sentimentSummary = NSAttributeDescription()
        sentimentSummary.name = "sentimentSummary"
        sentimentSummary.attributeType = .stringAttributeType
        sentimentSummary.isOptional = true

        let isAnalyzing = NSAttributeDescription()
        isAnalyzing.name = "isAnalyzing"
        isAnalyzing.attributeType = .booleanAttributeType
        isAnalyzing.isOptional = false
        isAnalyzing.defaultValue = false

        let tag = NSAttributeDescription()
        tag.name = "tag"
        tag.attributeType = .stringAttributeType
        tag.isOptional = true

        entity.properties = [
            id,
            title,
            content,
            createdAt,
            updatedAt,
            sentimentScore,
            sentimentLabel,
            sentimentEmoji,
            sentimentSummary,
            isAnalyzing,
            tag
        ]

        model.entities = [entity]
        return model
    }
}

@objc(DiaryEntryEntity)
final class DiaryEntryEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var content: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var sentimentScore: NSNumber?
    @NSManaged var sentimentLabel: String?
    @NSManaged var sentimentEmoji: String?
    @NSManaged var sentimentSummary: String?
    @NSManaged var isAnalyzing: Bool
    @NSManaged var tag: String?

    @nonobjc class func fetchRequestAll() -> NSFetchRequest<DiaryEntryEntity> {
        let request = NSFetchRequest<DiaryEntryEntity>(entityName: "DiaryEntryEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }
}

extension DiaryEntryEntity {
    func toDiaryEntry() -> DiaryEntry {
        let sentiment: DiaryEntry.Sentiment?
        if let label = sentimentLabel,
           let emoji = sentimentEmoji,
           let summary = sentimentSummary,
           let scoreNumber = sentimentScore {
            sentiment = DiaryEntry.Sentiment(
                score: scoreNumber.doubleValue,
                label: label,
                emoji: emoji,
                summary: summary
            )
        } else {
            sentiment = nil
        }

        let tag: DiaryTag? = self.tag.flatMap { DiaryTag(rawValue: $0) }

        return DiaryEntry(
            id: id,
            title: title,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sentiment: sentiment,
            tag: tag,
            isAnalyzing: isAnalyzing
        )
    }
}
