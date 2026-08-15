import Carbon.HIToolbox
import Foundation

final class GlobalHotKeyManager: @unchecked Sendable {
    private var hotKeyReferences: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerReference: EventHandlerRef?
    fileprivate var actions: [UInt32: @MainActor @Sendable () -> Void] = [:]

    @discardableResult
    func register(
        shortcut: GlobalShortcut,
        id: UInt32 = 1,
        onPressed: @escaping @MainActor @Sendable () -> Void
    ) -> Bool {
        unregister(id: id)
        if eventHandlerReference == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let handlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                globalHotKeyHandler,
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerReference
            )
            guard handlerStatus == noErr else {
                unregister()
                return false
            }
        }

        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("DVSR"), id: id)
        let (keyCode, modifiers): (UInt32, UInt32) = switch shortcut {
        case .optionSpace: (UInt32(kVK_Space), UInt32(optionKey))
        case .optionShiftSpace: (UInt32(kVK_Space), UInt32(optionKey | shiftKey))
        case .commandShiftSpace: (UInt32(kVK_Space), UInt32(cmdKey | shiftKey))
        case .controlOptionSpace: (UInt32(kVK_Space), UInt32(controlKey | optionKey))
        case .controlOptionT: (UInt32(kVK_ANSI_T), UInt32(controlKey | optionKey))
        }
        var reference: EventHotKeyRef?
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard registrationStatus == noErr, let reference else { return false }
        hotKeyReferences[id] = reference
        actions[id] = onPressed
        return true
    }

    func unregister(id: UInt32) {
        if let reference = hotKeyReferences.removeValue(forKey: id) {
            UnregisterEventHotKey(reference)
        }
        actions.removeValue(forKey: id)
    }

    func unregister() {
        hotKeyReferences.values.forEach { UnregisterEventHotKey($0) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
        hotKeyReferences = [:]
        eventHandlerReference = nil
        actions = [:]
    }

    deinit { unregister() }
}

private let globalHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, let action = manager.actions[hotKeyID.id] else {
        return OSStatus(eventNotHandledErr)
    }
    Task { @MainActor in action() }
    return noErr
}

private func fourCharacterCode(_ value: String) -> OSType {
    value.utf8.prefix(4).reduce(0) { ($0 << 8) | OSType($1) }
}
