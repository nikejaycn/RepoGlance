import Foundation

enum PathNormalizer {
    static func canonicalPath(for url: URL) -> String {
        let standardized = url.standardizedFileURL.resolvingSymlinksInPath()
        let fileSystemCanonicalPath = try? standardized
            .resourceValues(forKeys: [.canonicalPathKey])
            .canonicalPath
        return (fileSystemCanonicalPath ?? standardized.path(percentEncoded: false))
            .trimmingTrailingSlashes()
    }

    static func isDescendant(_ child: String, of parent: String) -> Bool {
        guard child != parent else { return false }
        let prefix = parent == "/" ? "/" : parent + "/"
        return child.hasPrefix(prefix)
    }
}

private extension String {
    func trimmingTrailingSlashes() -> String {
        guard count > 1 else { return self }
        var result = self
        while result.hasSuffix("/") { result.removeLast() }
        return result
    }
}
