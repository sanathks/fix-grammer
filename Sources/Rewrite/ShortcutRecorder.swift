import SwiftUI
import AppKit
import Carbon

struct ShortcutRecorder: View {
    let label: String
    @Binding var shortcut: Shortcut
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Button(action: { isRecording.toggle() }) {
                Text(isRecording ? "Press shortcut..." : shortcut.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minWidth: 100)
            }
            .controlSize(.small)
            .background(
                ShortcutCaptureView(isRecording: $isRecording, shortcut: $shortcut)
                    .frame(width: 0, height: 0)
            )
        }
    }
}

/// Hidden NSView that captures key events when recording
struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: Shortcut

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = { keyCode, modifiers in
            shortcut = Shortcut(keyCode: keyCode, modifiers: modifiers)
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class ShortcutCaptureNSView: NSView {
    var isRecording = false
    var onCapture: ((UInt32, UInt32) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let mods = carbonModifiers(from: event.modifierFlags)
        // Require at least one modifier key
        guard mods != 0 else { return }
        // Ignore bare modifier keys (Shift, Ctrl, etc. without a letter)
        guard event.keyCode != 0xFF else { return }

        onCapture?(UInt32(event.keyCode), mods)
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore standalone modifier presses
    }
}
