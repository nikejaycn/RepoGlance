import XCTest
@testable import DevSearch

final class SearchServiceTests: XCTestCase {
    func testNameRanksBeforePathAndReadme() throws {
        let exact = project(path: "/tmp/dev-search", name: "Dev Search")
        var pathMatch = project(path: "/tmp/dev-search-archive/other", name: "Other")
        pathMatch.readmeExcerpt = "Dev Search documentation"

        let matches = SearchService.search([pathMatch, exact], query: "dev search")
        XCTAssertEqual(matches.first?.project.id, exact.id)
    }

    func testSearchesTagsDescriptionAndReadme() {
        var value = project(path: "/tmp/project", name: "Project")
        value.tags = ["macOS"]
        value.customDescription = "本地项目启动器"
        value.readmeExcerpt = "Repository finder"

        XCTAssertEqual(SearchService.search([value], query: "macos").count, 1)
        XCTAssertEqual(SearchService.search([value], query: "启动器").count, 1)
        XCTAssertEqual(SearchService.search([value], query: "finder").count, 1)
    }

    func testEmptyQueryPrioritizesFavoritesThenRecent() {
        var favorite = project(path: "/tmp/favorite", name: "Favorite")
        favorite.isFavorite = true
        var recent = project(path: "/tmp/recent", name: "Recent")
        recent.lastOpenedAt = .now

        XCTAssertEqual(SearchService.search([recent, favorite], query: "").first?.project.id, favorite.id)
    }

    func testTenThousandProjectSearchMeetsOneHundredMillisecondTarget() {
        let projects = (0..<10_000).map { index in
            var value = project(path: "/tmp/dev/project-\(index)", name: "Project \(index)")
            value.tags = index == 9_999 ? ["needle"] : ["swift"]
            value.readmeExcerpt = "A concise local project description."
            return value
        }

        let clock = ContinuousClock()
        let start = clock.now
        let matches = SearchService.search(projects, query: "needle")
        let elapsed = start.duration(to: clock.now)

        XCTAssertEqual(matches.first?.project.id, "/tmp/dev/project-9999")
        XCTAssertLessThan(elapsed, .milliseconds(100))
    }

    func testNonContiguousFuzzyMatchFindsProjectName() {
        let project = project(path: "/tmp/DevSearch", name: "Dev Search")

        let matches = SearchService.search([project], query: "dvs")

        XCTAssertEqual(matches.map(\.id), [project.id])
    }

    func testFuzzyNameMatchRanksBeforeFuzzyPathMatch() {
        let nameMatch = project(path: "/tmp/tools/DocumentViewService", name: "Document View Service")
        let pathMatch = project(path: "/tmp/drafts/versioned/source/Other", name: "Other")

        let matches = SearchService.search([pathMatch, nameMatch], query: "dvs")

        XCTAssertEqual(matches.first?.id, nameMatch.id)
    }

    func testMatchedNestedRepositoryStaysDirectlyAfterMatchedParent() {
        var parent = project(path: "/tmp/web", name: "Web")
        var child = project(path: "/tmp/web/services/api", name: "Web API")
        child.parentProjectID = parent.id
        let unrelated = project(path: "/tmp/web-archive", name: "Web Archive")
        parent.customDescription = "web workspace"

        let matches = SearchService.search([child, unrelated, parent], query: "web")

        let parentIndex = matches.firstIndex { $0.id == parent.id }
        let childIndex = matches.firstIndex { $0.id == child.id }
        XCTAssertEqual(childIndex, parentIndex.map { $0 + 1 })
    }

    private func project(path: String, name: String) -> ProjectRecord {
        ProjectRecord(canonicalPath: path, directoryName: name, scanRootPath: "/tmp")
    }
}
