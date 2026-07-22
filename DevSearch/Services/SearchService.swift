import Foundation

struct SearchMatch: Identifiable, Sendable {
    let project: ProjectRecord
    let score: Int
    let matchedExcerpt: String?
    var id: String { project.id }
}

enum SearchService {
    static func search(_ projects: [ProjectRecord], query: String, limit: Int = 200) -> [SearchMatch] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else {
            return projects
                .filter { $0.availability != .missing }
                .sorted(by: emptyQueryOrdering)
                .prefix(limit)
                .map { SearchMatch(project: $0, score: 0, matchedExcerpt: nil) }
        }

        let fuzzyNeedle = normalizedFuzzyScalars(needle)
        let ranked = projects.compactMap { project -> SearchMatch? in
            let name = project.name.lowercased()
            let directoryName = project.directoryName.lowercased()
            let path = project.canonicalPath.lowercased()
            let description = project.customDescription.lowercased()
            let tags = project.tags.joined(separator: " ").lowercased()
            let readme = (project.readmeExcerpt ?? "").lowercased()

            var score = 0
            var excerpt: String?

            if name == needle { score += 1_200 }
            else if name.hasPrefix(needle) { score += 1_000 }
            else if name.contains(needle) { score += 800 }
            else if directoryName.contains(needle) { score += 700 }

            if tags.contains(needle) { score += 500 }
            if path.contains(needle) { score += 350 }
            if description.contains(needle) {
                score += 250
                excerpt = project.customDescription
            }
            if readme.contains(needle) {
                score += 100
                if excerpt == nil { excerpt = project.readmeExcerpt }
            }

            if score == 0 {
                if let fuzzy = fuzzySubsequenceScore(source: name, query: fuzzyNeedle) {
                    score += 600 + fuzzy
                } else if let fuzzy = fuzzySubsequenceScore(source: directoryName, query: fuzzyNeedle) {
                    score += 550 + fuzzy
                } else if let fuzzy = fuzzySubsequenceScore(source: tags, query: fuzzyNeedle) {
                    score += 400 + fuzzy
                } else if let fuzzy = fuzzySubsequenceScore(source: path, query: fuzzyNeedle) {
                    score += 300 + fuzzy
                }
            }
            if project.isFavorite { score += 30 }
            if project.lastOpenedAt != nil { score += 10 }

            guard score > 0 else { return nil }
            return SearchMatch(project: project, score: score, matchedExcerpt: excerpt)
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return projectOrdering($0.project, $1.project)
        }
        return hierarchyOrdered(ranked).prefix(limit).map { $0 }
    }

    private static func emptyQueryOrdering(_ lhs: ProjectRecord, _ rhs: ProjectRecord) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        return projectOrdering(lhs, rhs)
    }

    private static func projectOrdering(_ lhs: ProjectRecord, _ rhs: ProjectRecord) -> Bool {
        switch (lhs.lastOpenedAt, rhs.lastOpenedAt) {
        case let (left?, right?) where left != right:
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func hierarchyOrdered(_ ranked: [SearchMatch]) -> [SearchMatch] {
        let matchByID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.id, $0) })
        var childrenByParent: [String: [SearchMatch]] = [:]
        for match in ranked {
            if let parentID = match.project.parentProjectID, matchByID[parentID] != nil {
                childrenByParent[parentID, default: []].append(match)
            }
        }

        var visited = Set<String>()
        var ordered: [SearchMatch] = []
        func appendTree(_ match: SearchMatch) {
            guard visited.insert(match.id).inserted else { return }
            ordered.append(match)
            for child in childrenByParent[match.id] ?? [] { appendTree(child) }
        }

        for match in ranked where match.project.parentProjectID.flatMap({ matchByID[$0] }) == nil {
            appendTree(match)
        }
        for match in ranked { appendTree(match) }
        return ordered
    }

    private static func fuzzySubsequenceScore(
        source: String,
        query: [UnicodeScalar]
    ) -> Int? {
        guard !query.isEmpty else { return nil }
        var queryIndex = 0
        var previousMatchIndex: Int?
        var firstMatchIndex: Int?
        var score = 0
        var sourceIndex = 0

        for scalar in source.unicodeScalars where CharacterSet.alphanumerics.contains(scalar) {
            if queryIndex < query.count, scalar == query[queryIndex] {
                firstMatchIndex = firstMatchIndex ?? sourceIndex
                score += previousMatchIndex == sourceIndex - 1 ? 8 : 2
                previousMatchIndex = sourceIndex
                queryIndex += 1
            }
            sourceIndex += 1
        }

        guard queryIndex == query.count else { return nil }
        score += max(0, 40 - (firstMatchIndex ?? 40))
        score += max(0, 30 - (sourceIndex - query.count))
        return score
    }

    private static func normalizedFuzzyScalars(_ value: String) -> [UnicodeScalar] {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        return folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    }
}
