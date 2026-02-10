import AppKit
import SwiftUI

final class RewriteModesWindow {
    private static var window: NSWindow?

    static func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = RewriteModesView()
            .frame(minWidth: 460, minHeight: 400)
        let hosting = NSHostingController(rootView: view)
        hosting.preferredContentSize = NSSize(width: 460, height: 400)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Rewrite Modes"
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 460, height: 400))
        win.minSize = NSSize(width: 360, height: 300)
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = win
    }
}

struct RewriteModesView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var selectedModeId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(settings.rewriteModes) { mode in
                        ModeTab(
                            name: mode.name.isEmpty ? "Untitled" : mode.name,
                            isSelected: selectedModeId == mode.id,
                            onSelect: { selectedModeId = mode.id },
                            onDelete: {
                                let idx = settings.rewriteModes.firstIndex(where: { $0.id == mode.id })
                                settings.rewriteModes.removeAll { $0.id == mode.id }
                                // Select a neighbor tab after deletion.
                                if selectedModeId == mode.id {
                                    if let idx, !settings.rewriteModes.isEmpty {
                                        let next = min(idx, settings.rewriteModes.count - 1)
                                        selectedModeId = settings.rewriteModes[next].id
                                    } else {
                                        selectedModeId = nil
                                    }
                                }
                            }
                        )
                    }

                    Button {
                        let newMode = RewriteMode(id: UUID(), name: "", prompt: "")
                        settings.rewriteModes.append(newMode)
                        selectedModeId = newMode.id
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }

            Divider()

            // Content for selected mode
            if let binding = selectedModeBinding {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Name")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 44, alignment: .trailing)
                        TextField("Mode name", text: binding.name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    .padding(.top, 4)

                    HStack(alignment: .top, spacing: 8) {
                        Text("Prompt")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 44, alignment: .trailing)
                            .padding(.top, 4)
                        TextEditor(text: binding.prompt)
                            .font(.system(size: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(12)
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Text("Select a mode or add a new one")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            if selectedModeId == nil, let first = settings.rewriteModes.first {
                selectedModeId = first.id
            }
        }
    }

    private var selectedModeBinding: Binding<RewriteMode>? {
        guard let id = selectedModeId,
              let idx = settings.rewriteModes.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $settings.rewriteModes[idx]
    }
}

private struct ModeTab: View {
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                if isHovered || isSelected {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}
