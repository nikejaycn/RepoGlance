import Foundation

enum ClipboardSearchService {
    static func search(
        _ items: [ClipboardItem],
        query: String,
        limit: Int = 500
    ) -> [ClipboardItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limit > 0 else { return [] }
        guard !cleanQuery.isEmpty else { return Array(items.prefix(limit)) }
        return Array(items.lazy.filter {
            $0.text.localizedCaseInsensitiveContains(cleanQuery)
        }.prefix(limit))
    }
}
