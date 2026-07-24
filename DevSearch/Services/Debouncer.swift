import Foundation

@MainActor
final class Debouncer {
    private let delay: Duration
    private var task: Task<Void, Never>?

    init(delay: Duration) {
        self.delay = delay
    }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor [delay] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
