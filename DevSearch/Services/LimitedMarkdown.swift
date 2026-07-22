import Foundation

enum LimitedMarkdown {
    /// Keeps text-oriented Markdown while removing remote media, raw HTML and
    /// clickable destinations. Preview links are rendered as their labels so
    /// untrusted README content cannot trigger navigation or custom URL schemes.
    static func sanitize(_ source: String) -> String {
        source
            .replacingOccurrences(
                of: #"<script\b[^>]*>[\s\S]*?</script\s*>"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"<iframe\b[^>]*>[\s\S]*?</iframe\s*>"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"!\[([^\]]*)\]\([^\)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]*\)"#, with: "$1", options: .regularExpression)
    }
}
