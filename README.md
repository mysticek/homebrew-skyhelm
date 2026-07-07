# Skyhelm — Homebrew tap & installer

**Voice-first command center for AI coding agents** (Claude Code, Codex). Supervise, approve and steer your agents from your phone — on your Wi-Fi, or anywhere via the end-to-end-encrypted relay. → https://skyhelm.dev

This repo is the public **distribution channel**: a Homebrew formula + a one-line installer that fetch a prebuilt, source-free release. The Skyhelm source lives in a private repo.

## Install

**Homebrew (macOS):**
```sh
brew install mysticek/skyhelm/skyhelm
```

**Script (macOS & Linux):**
```sh
curl -fsSL https://raw.githubusercontent.com/mysticek/homebrew-skyhelm/main/install.sh | bash
```

Then finish setup (pick a workspace, get your pairing QR):
```sh
skyhelm setup
```

## Requirements
- **macOS or Linux** (Windows via WSL)
- **Node.js 20+** (Homebrew installs it automatically)
- **A coding agent:** [Claude Code](https://docs.claude.com/claude-code) (`claude`) or [Codex](https://github.com/openai/codex) (`codex`)
- `tmux` (installed automatically) · **no Docker, no database server** (embedded PGlite)

Voice speech-to-text and local memory (≈2 GB of models: whisper + ollama) are **optional** and off by default — add them anytime with `skyhelm setup` or `CATO_WITH_MODELS=1`.

## Update / uninstall
```sh
brew upgrade skyhelm      # or: skyhelm update
brew uninstall skyhelm
```
