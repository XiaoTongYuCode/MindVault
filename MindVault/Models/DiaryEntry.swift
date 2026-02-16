import Foundation

enum DiaryTag: String, CaseIterable, Hashable, Codable {
    case study = "学习"
    case work = "工作"
    case family = "家庭"
    case health = "健康"
    case travel = "旅行"
    case hobby = "爱好"
    case relationship = "情感"
    case reflection = "思考"
    case other = "其他"
    
    var emoji: String {
        switch self {
        case .study: return "📚"
        case .work: return "💼"
        case .family: return "👨‍👩‍👧‍👦"
        case .health: return "🏃"
        case .travel: return "✈️"
        case .hobby: return "🎨"
        case .relationship: return "💕"
        case .reflection: return "🤔"
        case .other: return "📝"
        }
    }
    
    /// 获取本地化键（用于本地化字符串）
    var localizationKey: String {
        switch self {
        case .study: return "tag.study"
        case .work: return "tag.work"
        case .family: return "tag.family"
        case .health: return "tag.health"
        case .travel: return "tag.travel"
        case .hobby: return "tag.hobby"
        case .relationship: return "tag.relationship"
        case .reflection: return "tag.reflection"
        case .other: return "tag.other"
        }
    }
    
    /// 获取本地化后的显示文本
    var localizedName: String {
        return localizationKey.localized
    }
    
    /// 从中文标签字符串创建 DiaryTag（向后兼容）
    /// 用于解析 SentimentAnalyzer 返回的中文标签
    static func from(chineseTag: String) -> DiaryTag? {
        return DiaryTag.allCases.first { $0.rawValue == chineseTag }
    }
    
    /// 从英文标签字符串创建 DiaryTag
    /// 用于解析 SentimentAnalyzer 返回的英文标签
    static func from(englishTag: String) -> DiaryTag? {
        let englishTagLower = englishTag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch englishTagLower {
        case "study": return .study
        case "work": return .work
        case "family": return .family
        case "health": return .health
        case "travel": return .travel
        case "hobby": return .hobby
        case "relationship": return .relationship
        case "reflection": return .reflection
        case "other": return .other
        default: return nil
        }
    }
}

struct DiaryEntry: Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var sentiment: Sentiment?
    var tag: DiaryTag?
    var isAnalyzing: Bool

    struct Sentiment: Hashable {
        let score: Double      // [-1, 1]
        let label: String      // "积极" | "中性" | "消极"
        let emoji: String
        let summary: String
    }
}
