import Foundation

struct ReadmeContent: Equatable, Sendable {
    let url: URL
    let excerpt: String
    let wasTruncated: Bool
}

enum ReadmeService {
    static let maximumBytes = 20 * 1024

    static func readme(in projectURL: URL, fileManager: FileManager = .default) -> ReadmeContent? {
        guard let names = try? fileManager.contentsOfDirectory(atPath: projectURL.path) else {
            return nil
        }

        let selectedName = selectReadmeName(from: names)
        guard let selectedName else { return nil }

        let url = projectURL.appendingPathComponent(selectedName, isDirectory: false)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data = (try? handle.read(upToCount: maximumBytes + 1)) ?? Data()
        let wasTruncated = data.count > maximumBytes
        let limitedData = Data(data.prefix(maximumBytes))
        let excerpt = validUTF8Prefix(from: limitedData)
        return ReadmeContent(url: url, excerpt: excerpt, wasTruncated: wasTruncated)
    }

    static func selectReadmeName(from names: [String]) -> String? {
        let exactPriority = ["README.md", "README.mdx", "README.txt", "README"]
        for candidate in exactPriority where names.contains(candidate) {
            return candidate
        }

        let indexed = Dictionary(grouping: names, by: { $0.lowercased() })
        for candidate in exactPriority {
            if let actual = indexed[candidate.lowercased()]?.sorted().first {
                return actual
            }
        }
        return nil
    }

    private static func validUTF8Prefix(from data: Data) -> String {
        if let value = String(data: data, encoding: .utf8) { return value }

        var end = data.count
        while end > 0 {
            end -= 1
            if let value = String(data: data.prefix(end), encoding: .utf8) {
                return value
            }
        }
        return ""
    }
}
