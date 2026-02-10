import Carbon
import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var grammarHotKeyRef: EventHotKeyRef?
    private var rewriteHotKeyRef: EventHotKeyRef?
    private var onGrammar: (() -> Void)?
    private var onRewrite: (() -> Void)?
    private var handlerInstalled = false

    private init() {}

    func register(
        grammar: Shortcut,
        rewrite: Shortcut,
        onGrammar: @escaping () -> Void,
        onRewrite: @escaping () -> Void
    ) {
        self.onGrammar = onGrammar
        self.onRewrite = onRewrite

        if !handlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(
                GetApplicationEventTarget(),
                hotkeyHandler,
                1,
                &eventType,
                selfPtr,
                nil
            )
            handlerInstalled = true
        }

        registerKey(shortcut: grammar, id: 1, ref: &grammarHotKeyRef)
        registerKey(shortcut: rewrite, id: 2, ref: &rewriteHotKeyRef)
    }

    func updateShortcuts(grammar: Shortcut, rewrite: Shortcut) {
        unregisterKey(ref: &grammarHotKeyRef)
        unregisterKey(ref: &rewriteHotKeyRef)
        registerKey(shortcut: grammar, id: 1, ref: &grammarHotKeyRef)
        registerKey(shortcut: rewrite, id: 2, ref: &rewriteHotKeyRef)
    }

    private func registerKey(shortcut: Shortcut, id: UInt32, ref: inout EventHotKeyRef?) {
        let hotKeyID = EventHotKeyID(signature: 0x47465852, id: id)
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
    }

    private func unregisterKey(ref: inout EventHotKeyRef?) {
        if let r = ref {
            UnregisterEventHotKey(r)
            ref = nil
        }
    }

    fileprivate func handleHotkey(id: UInt32) {
        switch id {
        case 1: onGrammar?()
        case 2: onRewrite?()
        default: break
        }
    }
}

private func hotkeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event, let userData = userData else {
        return OSStatus(eventNotHandledErr)
    }
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotkey(id: hotKeyID.id)
    return noErr
}
