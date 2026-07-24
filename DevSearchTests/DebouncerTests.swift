import XCTest
@testable import DevSearch

@MainActor
final class DebouncerTests: XCTestCase {
    func testRapidSchedulingOnlyPerformsLatestAction() async throws {
        let debouncer = Debouncer(delay: .milliseconds(60))
        var performed: [String] = []

        debouncer.schedule { performed.append("r") }
        debouncer.schedule { performed.append("re") }
        debouncer.schedule { performed.append("repo") }

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(performed, ["repo"])
    }

    func testCancellationPreventsPendingAction() async throws {
        let debouncer = Debouncer(delay: .milliseconds(40))
        var didPerform = false

        debouncer.schedule { didPerform = true }
        debouncer.cancel()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertFalse(didPerform)
    }
}
