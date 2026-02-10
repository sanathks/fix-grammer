# Rewrite

<div align="center">

# ✏️

</div>

A lightweight macOS menu bar app for system-wide grammar correction and text rewriting, powered by local LLMs via [Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai). Select text in any app, hit a keyboard shortcut, and get instant results.

All processing happens locally. No data leaves your machine.

## Install

### Homebrew

```bash
brew tap sanathks/rewrite
brew install rewrite
```

To build from source instead of downloading the prebuilt binary:

```bash
brew install --HEAD rewrite
```

### Manual

Requires macOS 13+ and Swift toolchain (Xcode or Command Line Tools).

```bash
git clone https://github.com/sanathks/rewrite.git
cd rewrite
chmod +x Scripts/build.sh Scripts/install.sh
./Scripts/build.sh
./Scripts/install.sh
```

### Prerequisites

- [Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai) installed and running
- For Ollama, pull a model (default: `gemma3`):
  ```bash
  ollama pull gemma3
  ```
- For LM Studio, load a model and start the local server (default port: `1234`)

## Usage

1. Launch **Rewrite** -- a checkmark icon appears in the menu bar
2. Select text in any app (browser, Slack, Notes, TextEdit, etc.)
3. Press `Ctrl+Shift+G` to silently fix grammar (text is replaced in-place, no popup)
4. Press `Ctrl+Shift+T` to open the rewrite popup with mode selection
5. Click **Replace** to swap the original text, or **Copy** to copy to clipboard

Press `Esc` to dismiss the popup.

## Rewrite Modes

The rewrite popup runs your default mode immediately and shows mode pills to switch between:

- **Clarity** -- simplifies text for maximum readability
- **My Tone** -- rewrites to match your personal tone description
- **Humanize** -- makes AI-generated text sound natural
- **Professional** -- polished business communication tone

Modes are fully configurable. Add, remove, or edit modes and their prompts via **Configure...** in settings.

## Configuration

Click the menu bar icon to access settings:

![Settings](screenshots/settings.png)

- **Server URL** -- default: `http://localhost:11434` (Ollama) or `http://localhost:1234` (LM Studio)
- **Model** -- auto-detected from your LLM server
- **Rewrite Modes** -- click Configure to edit mode names and prompts
- **Shortcuts** -- click to rebind the grammar and rewrite hotkeys
- **Default Mode** -- choose which mode the grammar shortcut uses (Grammar Fix or any rewrite mode)

Settings persist across app restarts.

## How It Works

Rewrite uses the macOS Accessibility API to read selected text from any app. When you trigger a shortcut:

1. Reads the selected text via accessibility
2. Sends it to your local LLM server with a tailored prompt
3. For grammar fix: silently replaces the text in-place
4. For rewrite: shows a popup near your selection with mode options and the result
5. On "Replace", writes the corrected text back into the source app via accessibility

## License

MIT
