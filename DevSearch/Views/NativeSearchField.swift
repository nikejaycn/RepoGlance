import AppKit
import SwiftUI

struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var focusOnAppear = true
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var onSubmit: () -> Void = {}
    var onChooseOpeningMethod: () -> Void = {}
    var onRevealInFinder: () -> Void = {}
    var onEditProject: () -> Void = {}
    var onRefresh: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onEnterPreview: () -> Void = {}
    var onSelectProjects: () -> Void = {}
    var onSelectClipboard: () -> Void = {}
    var onCopySelection: () -> Void = {}
    var onDeleteSelection: () -> Void = {}
    var onClearClipboardHistory: () -> Void = {}
    var onEscape: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = ActionSearchField()
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.valueChanged(_:))
        field.controlSize = .large
        field.identifier = NSUserInterfaceItemIdentifier("search-field")
        field.setAccessibilityIdentifier("search-field")
        field.onMoveUp = onMoveUp
        field.onMoveDown = onMoveDown
        field.onChooseOpeningMethod = onChooseOpeningMethod
        field.onRevealInFinder = onRevealInFinder
        field.onEditProject = onEditProject
        field.onRefresh = onRefresh
        field.onOpenSettings = onOpenSettings
        field.onEnterPreview = onEnterPreview
        field.onSelectProjects = onSelectProjects
        field.onSelectClipboard = onSelectClipboard
        field.onCopySelection = onCopySelection
        field.onDeleteSelection = onDeleteSelection
        field.onClearClipboardHistory = onClearClipboardHistory
        field.focusWhenAttachedToWindow = focusOnAppear
        context.coordinator.installArrowKeyMonitor(for: field)

        return field
    }

    static func dismantleNSView(_ field: NSSearchField, coordinator: Coordinator) {
        coordinator.removeArrowKeyMonitor()
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = placeholder
        context.coordinator.update(owner: self)
        guard let field = field as? ActionSearchField else { return }
        field.onMoveUp = onMoveUp
        field.onMoveDown = onMoveDown
        field.onChooseOpeningMethod = onChooseOpeningMethod
        field.onRevealInFinder = onRevealInFinder
        field.onEditProject = onEditProject
        field.onRefresh = onRefresh
        field.onOpenSettings = onOpenSettings
        field.onEnterPreview = onEnterPreview
        field.onSelectProjects = onSelectProjects
        field.onSelectClipboard = onSelectClipboard
        field.onCopySelection = onCopySelection
        field.onDeleteSelection = onDeleteSelection
        field.onClearClipboardHistory = onClearClipboardHistory
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var onMoveUp: () -> Void
        var onMoveDown: () -> Void
        var onSubmit: () -> Void
        var onChooseOpeningMethod: () -> Void
        var onRevealInFinder: () -> Void
        var onEscape: () -> Void
        var onEnterPreview: () -> Void
        private var arrowKeyMonitor: Any?

        init(owner: NativeSearchField) {
            text = owner.$text
            onMoveUp = owner.onMoveUp
            onMoveDown = owner.onMoveDown
            onSubmit = owner.onSubmit
            onChooseOpeningMethod = owner.onChooseOpeningMethod
            onRevealInFinder = owner.onRevealInFinder
            onEscape = owner.onEscape
            onEnterPreview = owner.onEnterPreview
        }

        func update(owner: NativeSearchField) {
            text = owner.$text
            onMoveUp = owner.onMoveUp
            onMoveDown = owner.onMoveDown
            onSubmit = owner.onSubmit
            onChooseOpeningMethod = owner.onChooseOpeningMethod
            onRevealInFinder = owner.onRevealInFinder
            onEscape = owner.onEscape
            onEnterPreview = owner.onEnterPreview
        }

        func installArrowKeyMonitor(for field: NSSearchField) {
            removeArrowKeyMonitor()
            arrowKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak field] event in
                guard field?.currentEditor() != nil else { return event }
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let shortcutModifiers = modifiers.intersection([.command, .option, .control, .shift])
                if shortcutModifiers == .command, event.keyCode == 124 {
                    self?.onEnterPreview()
                    return nil
                }
                let textEditingModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                guard modifiers.intersection(textEditingModifiers).isEmpty else { return event }
                switch event.keyCode {
                case 125: self?.onMoveDown(); return nil
                case 126: self?.onMoveUp(); return nil
                default: return event
                }
            }
        }

        func removeArrowKeyMonitor() {
            guard let arrowKeyMonitor else { return }
            NSEvent.removeMonitor(arrowKeyMonitor)
            self.arrowKeyMonitor = nil
        }

        @objc func valueChanged(_ sender: NSSearchField) {
            text.wrappedValue = sender.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onMoveUp()
            case #selector(NSResponder.moveDown(_:)):
                onMoveDown()
            case #selector(NSResponder.insertNewline(_:)):
                let modifiers = NSApp.currentEvent?.modifierFlags ?? []
                if modifiers.contains(.command) { onChooseOpeningMethod() }
                else if modifiers.contains(.option) { onRevealInFinder() }
                else { onSubmit() }
            case #selector(NSResponder.cancelOperation(_:)):
                onEscape()
            default:
                return false
            }
            return true
        }
    }
}

@MainActor
private final class ActionSearchField: NSSearchField {
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var onChooseOpeningMethod: () -> Void = {}
    var onRevealInFinder: () -> Void = {}
    var onEditProject: () -> Void = {}
    var onRefresh: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onEnterPreview: () -> Void = {}
    var onSelectProjects: () -> Void = {}
    var onSelectClipboard: () -> Void = {}
    var onCopySelection: () -> Void = {}
    var onDeleteSelection: () -> Void = {}
    var onClearClipboardHistory: () -> Void = {}
    var focusWhenAttachedToWindow = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard focusWhenAttachedToWindow, window != nil else { return }
        focusWhenAttachedToWindow = false
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let character = event.charactersIgnoringModifiers?.lowercased()

        let shortcutModifiers = modifiers.intersection([.command, .option, .control, .shift])
        if shortcutModifiers == .command, event.keyCode == 124 {
            onEnterPreview()
            return true
        }

        if modifiers.contains(.command) {
            switch character {
            case "\r", "\u{3}": onChooseOpeningMethod(); return true
            case "1": onSelectProjects(); return true
            case "2": onSelectClipboard(); return true
            case "c" where currentEditor()?.selectedRange.length == 0:
                onCopySelection()
                return true
            case "k": onEditProject(); return true
            case "r": onRefresh(); return true
            case ",": onOpenSettings(); return true
            default: break
            }
            if event.keyCode == 51, stringValue.isEmpty {
                if modifiers.contains(.shift) {
                    onClearClipboardHistory()
                } else {
                    onDeleteSelection()
                }
                return true
            }
        } else if modifiers.contains(.option), character == "\r" || character == "\u{3}" {
            onRevealInFinder()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
