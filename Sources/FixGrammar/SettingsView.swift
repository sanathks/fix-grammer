import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var isConnected = false
    @State private var hasAccessibility = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FixGrammar")
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Ollama URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TextField("http://localhost:11434", text: $settings.ollamaURL)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        loadModels()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .disabled(isLoadingModels)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if availableModels.isEmpty {
                    HStack(spacing: 6) {
                        TextField("gemma3", text: $settings.modelName)
                            .textFieldStyle(.roundedBorder)
                        if isLoadingModels {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                } else {
                    Picker("", selection: $settings.modelName) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .labelsHidden()
                }
            }

            HStack {
                Text("Rewrite Modes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Configure...") {
                    RewriteModesWindow.show()
                }
                .controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Shortcuts (click to change)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ShortcutRecorder(label: "Fix Grammar", shortcut: $settings.grammarShortcut)
                ShortcutRecorder(label: "Rewrite", shortcut: $settings.rewriteShortcut)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Default Mode (Fix Grammar shortcut)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: defaultModeBinding) {
                    Text("Grammar Fix").tag("")
                    ForEach(settings.rewriteModes) { mode in
                        Text(mode.name).tag(mode.id.uuidString)
                    }
                }
                .labelsHidden()
            }

            Divider()

            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Ollama Connected" : "Ollama Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Circle()
                    .fill(hasAccessibility ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(hasAccessibility ? "Accessibility OK" : "Accessibility Required")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !hasAccessibility {
                    Spacer()
                    Button("Grant") {
                        AccessibilityService.requestPermission()
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .preferredColorScheme(.dark)
        .onAppear {
            loadModels()
            hasAccessibility = AccessibilityService.isTrusted()
        }
    }

    private var defaultModeBinding: Binding<String> {
        Binding(
            get: { settings.defaultModeId?.uuidString ?? "" },
            set: { newValue in
                settings.defaultModeId = newValue.isEmpty ? nil : UUID(uuidString: newValue)
            }
        )
    }

    private func loadModels() {
        isLoadingModels = true
        OllamaService.shared.fetchModels { models in
            DispatchQueue.main.async {
                availableModels = models
                isConnected = !models.isEmpty
                isLoadingModels = false
                if !models.isEmpty && !models.contains(settings.modelName) {
                    settings.modelName = models[0]
                }
            }
        }
    }
}
