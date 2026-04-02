import Foundation

public enum Sentiment: String, Codable, Hashable {
    case positive
    case negative
    case neutral
}

public struct News: Codable, Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let content: String
    public let source: String
    public let date: Date
    public let sentiment: Sentiment

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        source: String,
        date: Date,
        sentiment: Sentiment
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.date = date
        self.sentiment = sentiment
    }
}
