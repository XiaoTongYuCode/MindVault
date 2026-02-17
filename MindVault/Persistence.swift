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

        // MARK: - DiaryEntryEntity
        let entryEntity = NSEntityDescription()
        entryEntity.name = "DiaryEntryEntity"
        entryEntity.managedObjectClassName = NSStringFromClass(DiaryEntryEntity.self)

        let entryId = NSAttributeDescription()
        entryId.name = "id"
        entryId.attributeType = .UUIDAttributeType
        entryId.isOptional = false

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

        // MARK: - DiaryImageEntity
        let imageEntity = NSEntityDescription()
        imageEntity.name = "DiaryImageEntity"
        imageEntity.managedObjectClassName = NSStringFromClass(DiaryImageEntity.self)

        let imageId = NSAttributeDescription()
        imageId.name = "id"
        imageId.attributeType = .UUIDAttributeType
        imageId.isOptional = false

        let imageData = NSAttributeDescription()
        imageData.name = "imageData"
        imageData.attributeType = .binaryDataAttributeType
        imageData.isOptional = false
        imageData.allowsExternalBinaryDataStorage = true

        let orderIndex = NSAttributeDescription()
        orderIndex.name = "orderIndex"
        orderIndex.attributeType = .integer16AttributeType
        orderIndex.isOptional = false
        orderIndex.defaultValue = 0

        // MARK: - Relationships
        let imagesRelationship = NSRelationshipDescription()
        imagesRelationship.name = "images"
        imagesRelationship.destinationEntity = imageEntity
        imagesRelationship.minCount = 0
        imagesRelationship.maxCount = 0 // 0 means no upper bound
        imagesRelationship.deleteRule = .cascadeDeleteRule
        imagesRelationship.isOptional = true

        let entryRelationship = NSRelationshipDescription()
        entryRelationship.name = "entry"
        entryRelationship.destinationEntity = entryEntity
        entryRelationship.minCount = 1
        entryRelationship.maxCount = 1
        entryRelationship.deleteRule = .nullifyDeleteRule
        entryRelationship.isOptional = false

        imagesRelationship.inverseRelationship = entryRelationship
        entryRelationship.inverseRelationship = imagesRelationship

        entryEntity.properties = [
            entryId,
            title,
            content,
            createdAt,
            updatedAt,
            sentimentScore,
            sentimentLabel,
            sentimentEmoji,
            sentimentSummary,
            isAnalyzing,
            tag,
            imagesRelationship
        ]

        imageEntity.properties = [
            imageId,
            imageData,
            orderIndex,
            entryRelationship
        ]

        model.entities = [entryEntity, imageEntity]
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
    @NSManaged var images: NSSet?

    @nonobjc class func fetchRequestAll() -> NSFetchRequest<DiaryEntryEntity> {
        let request = NSFetchRequest<DiaryEntryEntity>(entityName: "DiaryEntryEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }
}

@objc(DiaryImageEntity)
final class DiaryImageEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var imageData: Data
    @NSManaged var orderIndex: Int16
    @NSManaged var entry: DiaryEntryEntity
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

        let imageEntities = (images as? Set<DiaryImageEntity>) ?? []
        let imageModels: [DiaryImage] = imageEntities
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { DiaryImage(id: $0.id, data: $0.imageData) }

        return DiaryEntry(
            id: id,
            title: title,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sentiment: sentiment,
            tag: tag,
            isAnalyzing: isAnalyzing,
            images: imageModels
        )
    }
}
