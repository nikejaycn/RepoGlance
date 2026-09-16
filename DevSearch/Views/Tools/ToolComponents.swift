import AppKit
import SwiftUI

struct ToolTextPane<Trailing: View>: View {
    let title: String
    @Binding var text: String
    let identifier: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ToolSectionHeader(title, trailing: trailing)
            ToolTextEditor(text: $text, identifier: identifier, label: title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ToolOutputPane<Trailing: View>: View {
    let title: String
    let text: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ToolSectionHeader(title, trailing: trailing)
            ReadOnlyTextView(text: text, label: title)
                .modifier(EditorSurface())
                .accessibilityIdentifier("toolbox-output")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ToolSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            trailing()
                .controlSize(.small)
        }
    }
}

struct ToolTextEditor: View {
    @Binding var text: String
    let identifier: String
    let label: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body.monospaced())
            .autocorrectionDisabled()
            .scrollContentBackground(.hidden)
            .padding(8)
            .modifier(EditorSurface())
            .focused($isFocused)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
            .onReceive(NotificationCenter.default.publisher(for: .toolboxFocusInput)) { _ in
                isFocused = true
            }
    }
}

struct ReadOnlyTextView: NSViewRepresentable {
    let text: String
    let label: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.setAccessibilityLabel(label)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        scrollView.identifier = NSUserInterfaceItemIdentifier("toolbox-output")
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textColor = .labelColor
        textView.setAccessibilityLabel(label)
        if textView.string != text { textView.string = text }
    }
}

struct ToolCopyButton: View {
    @EnvironmentObject private var model: AppModel
    let text: String
    var title = "复制"
    @State private var copied = false

    var body: some View {
        Button(copied ? "已复制" : title, systemImage: copied ? "checkmark" : "doc.on.doc") {
            model.copyToolboxText(text)
            copied = true
            Task {
                try? await Task.sleep(for: .milliseconds(1_500))
                copied = false
            }
        }
        .disabled(text.isEmpty)
        .keyboardShortcut("c", modifiers: [.command, .shift])
    }
}

struct TimestampResultRow: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let value: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
            Spacer()
            Button {
                model.copyToolboxText(value)
                copied = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1_500))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(value == "—")
            .help("复制 \(title)")
            .accessibilityLabel("复制 \(title)")
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
    }
}

struct ToolErrorLabel: View {
    let message: String
    init(_ message: String) { self.message = message }
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("toolbox-error")
    }
}

struct QRRequest: Hashable { let text: String; let level: QRCorrectionLevel; let size: Int }
struct EncodingRequest: Hashable { let input: String; let format: EncodingFormat; let direction: TransformDirection }
struct TimestampRequest: Hashable {
    let input: String
    let date: Date
    let direction: TimestampDirection
    let unit: TimestampUnit
    let timeZoneIdentifier: String
}
struct JSONRequest: Hashable { let input: String; let action: JSONToolAction; let indent: Int }
struct HashRequest: Hashable { let input: String; let algorithm: HashAlgorithm; let uppercase: Bool }
