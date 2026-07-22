import Foundation

struct IndexMergeService {
    static func merge(
        existing: [ProjectRecord],
        scanned: [ProjectRecord],
        activeRootPaths: Set<String>,
        exclusions: [ExclusionRule],
        issues: [ScanIssue]
    ) -> [ProjectRecord] {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let includedScanned = scanned.filter { !isExcluded($0.canonicalPath, by: exclusions) }
        let scannedIDs = Set(includedScanned.map(\.id))
        let offlineVolumeRoots = Set(issues
            .filter { $0.kind == .rootUnavailable && $0.rootPath.hasPrefix("/Volumes/") }
            .map(\.rootPath))

        var merged = includedScanned.map { project -> ProjectRecord in
            guard let old = existingByID[project.id] else { return project }
            return preservingUserMetadata(from: old, in: project)
        }

        for old in existing where !scannedIDs.contains(old.id) {
            if isExcluded(old.canonicalPath, by: exclusions) { continue }

            // A disabled or removed root was intentionally not part of this scan.
            // Keep its records unchanged instead of treating "not scanned" as "missing".
            guard activeRootPaths.contains(old.scanRootPath) else {
                merged.append(old)
                continue
            }

            var unavailable = old
            unavailable.availability = offlineVolumeRoots.contains(old.scanRootPath) ? .volumeOffline : .missing
            merged.append(unavailable)
        }

        return merged.sorted {
            $0.canonicalPath.localizedStandardCompare($1.canonicalPath) == .orderedAscending
        }
    }

    static func preservingUserMetadata(from old: ProjectRecord, in scanned: ProjectRecord) -> ProjectRecord {
        var value = scanned
        value.displayName = old.displayName
        value.customDescription = old.customDescription
        value.tags = old.tags
        value.isFavorite = old.isFavorite
        value.defaultEditorBundleIdentifier = old.defaultEditorBundleIdentifier
        value.firstSeenAt = old.firstSeenAt
        value.lastOpenedAt = old.lastOpenedAt
        return value
    }

    private static func isExcluded(_ path: String, by rules: [ExclusionRule]) -> Bool {
        rules.contains { rule in
            path == rule.canonicalPath
                || (rule.includesDescendants && PathNormalizer.isDescendant(path, of: rule.canonicalPath))
        }
    }
}
