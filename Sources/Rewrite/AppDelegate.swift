import AppKit
import SwiftUI
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSPanel?
    private var clickOutsideMonitor: Any?
    private var currentPanel: ResultPanel?
    private var cancellables = Set<AnyCancellable>()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeys()
        observeShortcutChanges()

        if !AccessibilityService.isTrusted() {
            AccessibilityService.requestPermission()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "text.badge.checkmark",
                accessibilityDescription: "Rewrite"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

    }

    private func setupHotkeys() {
        let settings = Settings.shared
        HotkeyManager.shared.register(
            grammar: settings.grammarShortcut,
            rewrite: settings.rewriteShortcut,
            onGrammar: { [weak self] in self?.handleGrammarHotkey() },
            onRewrite: { [weak self] in self?.handleRewriteHotkey() }
        )
    }

    private func observeShortcutChanges() {
        let settings = Settings.shared
        Publishers.CombineLatest(
            settings.$grammarShortcut,
            settings.$rewriteShortcut
        )
        .dropFirst()
        .sink { grammar, rewrite in
            HotkeyManager.shared.updateShortcuts(grammar: grammar, rewrite: rewrite)
        }
        .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        if let win = settingsWindow, win.isVisible {
            dismissSettings()
            return
        }

        guard let button = statusItem.button else { return }
        let buttonRect = button.window!.convertToScreen(button.convert(button.bounds, to: nil))

        let hosting = NSHostingController(rootView: SettingsView())
        hosting.view.layoutSubtreeIfNeeded()
        let contentSize = hosting.view.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isMovable = false

        let x = buttonRect.midX - contentSize.width / 2
        let y = buttonRect.minY - contentSize.height - 4
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = panel

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.dismissSettings()
        }
    }

    private func dismissSettings() {
        settingsWindow?.orderOut(nil)
        settingsWindow = nil
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    private func handleGrammarHotkey() {
        guard AccessibilityService.isTrusted() else {
            AccessibilityService.requestPermission()
            return
        }

        guard let text = AccessibilityService.shared.getSelectedText(), !text.isEmpty else {
            NSSound.beep()
            return
        }

        let settings = Settings.shared
        let prompt: String

        if let modeId = settings.defaultModeId,
           let mode = settings.rewriteModes.first(where: { $0.id == modeId }) {
            prompt = Prompts.rewrite(mode: mode, text: text)
        } else {
            prompt = Prompts.grammar(text: text)
        }

        OllamaService.shared.generate(prompt: prompt) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let corrected):
                    AccessibilityService.shared.replaceTextInSourceApp(corrected)
                case .failure:
                    NSSound.beep()
                }
            }
        }
    }

    private func handleRewriteHotkey() {
        guard AccessibilityService.isTrusted() else {
            AccessibilityService.requestPermission()
            return
        }

        guard let text = AccessibilityService.shared.getSelectedText(), !text.isEmpty else {
            return
        }

        let selectionRect = AccessibilityService.shared.getSelectionRect()
        let settings = Settings.shared
        let modes = settings.rewriteModes

        guard !modes.isEmpty else { return }

        // Pick default mode: use defaultModeId if it exists in modes, otherwise first mode
        let initialMode: RewriteMode
        if let modeId = settings.defaultModeId,
           let mode = modes.first(where: { $0.id == modeId }) {
            initialMode = mode
        } else {
            initialMode = modes[0]
        }

        currentPanel?.close()

        let panel = ResultPanel(modes: modes)
        currentPanel = panel

        func runMode(_ mode: RewriteMode) {
            let prompt = Prompts.rewrite(mode: mode, text: text)
            OllamaService.shared.generate(prompt: prompt) { result in
                switch result {
                case .success(let rewritten):
                    panel.updateResult(rewritten)
                case .failure(let err):
                    panel.updateError(err.localizedDescription)
                }
            }
        }

        panel.show(
            near: selectionRect,
            initialMode: initialMode,
            onModeSelected: { mode in
                runMode(mode)
            },
            onReplace: { [weak self] result in
                self?.currentPanel = nil
                AccessibilityService.shared.replaceTextInSourceApp(result)
            },
            onCopy: { [weak self] result in
                self?.currentPanel = nil
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
            }
        )

        // Immediately run the initial mode
        runMode(initialMode)
    }
}
