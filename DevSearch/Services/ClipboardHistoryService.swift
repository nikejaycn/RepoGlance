import Foundation

enum ClipboardHistoryService {
    static let maximumTextBytes = 100_000

    static func inserting(
        _ text: String,
        into items: [ClipboardItem],
        limit: Int,
        copiedAt: Date = .now,
        id: UUID = UUID()
    ) -> [ClipboardItem] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= maximumTextBytes,
              limit > 0
        else { return items }

        var result = items.filter { $0.text != text }
        result.insert(ClipboardItem(id: id, text: text, copiedAt: copiedAt), at: 0)
        return Array(result.prefix(limit))
    }
}
