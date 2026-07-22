import Foundation

struct ScanIssue: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case rootUnavailable
        case permissionDenied
        case enumerationFailed
    }

    let rootPath: String
    let path: String
    let kind: Kind
    let message: String
    var id: String { rootPath + ":" + path + ":" + message }
}

struct RepositoryScanResult: Sendable {
    let projects: [ProjectRecord]
    let issues: [ScanIssue]
}

actor GitRepositoryScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(
        roots: [ScanRoot],
        exclusions: [ExclusionRule],
        progress: (@Sendable (Int) async -> Void)? = nil,
        onDiscovery: (@Sendable (ProjectRecord) async -> Void)? = nil
    ) async -> RepositoryScanResult {
        var discovered: [String: DiscoveredRepository] = [:]
        var issues: [ScanIssue] = []
        var discoveryCount = 0

        let activeRoots = roots
            .filter(\.isEnabled)
            .sorted { pathDepth($0.canonicalPath) > pathDepth($1.canonicalPath) }

        for root in activeRoots {
            if Task.isCancelled { break }
            let rootURL = URL(fileURLWithPath: root.canonicalPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                issues.append(ScanIssue(
                    rootPath: root.canonicalPath,
                    path: root.canonicalPath,
                    kind: .rootUnavailable,
                    message: "扫描目录不可用"
                ))
                continue
            }

            if isGitRepository(at: rootURL), discovered[root.canonicalPath] == nil {
                discovered[root.canonicalPath] = DiscoveredRepository(path: root.canonicalPath, rootPath: root.canonicalPath)
                discoveryCount += 1
                await progress?(discoveryCount)
                if !isExcluded(root.canonicalPath, by: exclusions) {
                    await onDiscovery?(projectRecord(
                        path: root.canonicalPath,
                        rootPath: root.canonicalPath,
                        knownPaths: Array(discovered.keys)
                    ))
                }
            }

            let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isReadableKey]
            var enumerationErrors: [URL: Error] = [:]
            let options: FileManager.DirectoryEnumerationOptions = root.scanHiddenDirectories
                ? [.skipsPackageDescendants]
                : [.skipsHiddenFiles, .skipsPackageDescendants]

            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: keys,
                options: options,
                errorHandler: { url, error in
                    enumerationErrors[url] = error
                    return true
                }
            ) else {
                issues.append(ScanIssue(
                    rootPath: root.canonicalPath,
                    path: root.canonicalPath,
                    kind: .enumerationFailed,
                    message: "无法读取扫描目录"
                ))
                continue
            }

            while let item = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }

                let values = try? item.resourceValues(forKeys: Set(keys))
                guard values?.isDirectory == true else { continue }

                let canonical = PathNormalizer.canonicalPath(for: item)
                let depth = max(0, pathDepth(canonical) - pathDepth(root.canonicalPath))
                if depth > root.maximumDepth {
                    enumerator.skipDescendants()
                    continue
                }

                if values?.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }

                if root.ignoredDirectoryNames.contains(item.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }

                if isIgnoredRelativePath(canonical, in: root) {
                    enumerator.skipDescendants()
                    continue
                }

                if isGitRepository(at: item) {
                    let existing = discovered[canonical]
                    if existing == nil || pathDepth(root.canonicalPath) > pathDepth(existing!.rootPath) {
                        discovered[canonical] = DiscoveredRepository(path: canonical, rootPath: root.canonicalPath)
                    }
                    discoveryCount += 1
                    await progress?(discoveryCount)
                    if !isExcluded(canonical, by: exclusions) {
                        await onDiscovery?(projectRecord(
                            path: canonical,
                            rootPath: root.canonicalPath,
                            knownPaths: Array(discovered.keys)
                        ))
                    }
                }
            }

            for (url, error) in enumerationErrors {
                let nsError = error as NSError
                let kind: ScanIssue.Kind = nsError.code == NSFileReadNoPermissionError
                    ? .permissionDenied
                    : .enumerationFailed
                issues.append(ScanIssue(
                    rootPath: root.canonicalPath,
                    path: url.path,
                    kind: kind,
                    message: error.localizedDescription
                ))
            }
        }

        let allPaths = discovered.keys.sorted {
            if pathDepth($0) != pathDepth($1) { return pathDepth($0) < pathDepth($1) }
            return $0.localizedStandardCompare($1) == .orderedAscending
        }

        let projects = allPaths.compactMap { path -> ProjectRecord? in
            guard let repository = discovered[path], !isExcluded(path, by: exclusions) else { return nil }
            let parent = allPaths
                .filter { PathNormalizer.isDescendant(path, of: $0) }
                .max { pathDepth($0) < pathDepth($1) }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            let readme = ReadmeService.readme(in: url, fileManager: fileManager)
            return ProjectRecord(
                canonicalPath: path,
                directoryName: url.lastPathComponent,
                scanRootPath: repository.rootPath,
                parentProjectID: parent,
                readmePath: readme?.url.path,
                readmeExcerpt: readme?.excerpt,
                readmeWasTruncated: readme?.wasTruncated ?? false
            )
        }

        return RepositoryScanResult(projects: projects, issues: issues)
    }

    func isGitRepository(at directoryURL: URL) -> Bool {
        let gitURL = directoryURL.appendingPathComponent(".git", isDirectory: false)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: gitURL.path, isDirectory: &isDirectory) else { return false }
        if isDirectory.boolValue { return true }

        guard
            let data = try? Data(contentsOf: gitURL, options: [.mappedIfSafe]),
            let text = String(data: data.prefix(4_096), encoding: .utf8),
            let firstLine = text.split(whereSeparator: \.isNewline).first,
            firstLine.lowercased().hasPrefix("gitdir:")
        else { return false }

        let pointer = firstLine.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        guard !pointer.isEmpty else { return false }
        let target = URL(fileURLWithPath: String(pointer), relativeTo: directoryURL).standardizedFileURL
        var targetIsDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: target.path, isDirectory: &targetIsDirectory) && targetIsDirectory.boolValue
    }

    private func isExcluded(_ path: String, by rules: [ExclusionRule]) -> Bool {
        rules.contains { rule in
            path == rule.canonicalPath || (rule.includesDescendants && PathNormalizer.isDescendant(path, of: rule.canonicalPath))
        }
    }

    private func isIgnoredRelativePath(_ path: String, in root: ScanRoot) -> Bool {
        guard PathNormalizer.isDescendant(path, of: root.canonicalPath) else { return false }
        let relativePath = String(path.dropFirst(root.canonicalPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return root.ignoredRelativePaths.contains { rawRule in
            let rule = rawRule
                .replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !rule.isEmpty, !rule.split(separator: "/").contains("..") else { return false }
            return relativePath == rule || relativePath.hasPrefix(rule + "/")
        }
    }

    private func projectRecord(path: String, rootPath: String, knownPaths: [String]) -> ProjectRecord {
        let parent = knownPaths
            .filter { PathNormalizer.isDescendant(path, of: $0) }
            .max { pathDepth($0) < pathDepth($1) }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let readme = ReadmeService.readme(in: url, fileManager: fileManager)
        return ProjectRecord(
            canonicalPath: path,
            directoryName: url.lastPathComponent,
            scanRootPath: rootPath,
            parentProjectID: parent,
            readmePath: readme?.url.path,
            readmeExcerpt: readme?.excerpt,
            readmeWasTruncated: readme?.wasTruncated ?? false
        )
    }

    private func pathDepth(_ path: String) -> Int {
        URL(fileURLWithPath: path).pathComponents.count
    }
}

private struct DiscoveredRepository: Sendable {
    let path: String
    let rootPath: String
}
