#!/usr/bin/env bash
# Skyhelm installer (PUBLIC) — one command sets up the whole local stack from a prebuilt release.
# It does NOT clone any source; it downloads a self-contained tarball and installs prod deps.
# Cross-platform: macOS (Homebrew) and Linux (apt/dnf/pacman). Windows: run under WSL.
#
#   curl -fsSL https://getcato.dev/install.sh | bash
#   # or, from a checkout of this file:  ./install.sh
#
# No Docker, no database server — the DB is embedded (PGlite). Idempotent.
#
# Env knobs:
#   CATO_DIST=<url>        override the release tarball URL
#   CATO_SKIP_MODELS=1     skip the big whisper/ollama model downloads (get them later via `skyhelm setup`)
set -uo pipefail

# Source of the prebuilt, source-free tarball (top dir inside must be `cato/`). The
# homebrew-skyhelm repo + release are created later by the maintainer; this just points at them.
CATO_DIST="${CATO_DIST:-https://github.com/mysticek/homebrew-skyhelm/releases/latest/download/skyhelm.tar.gz}"

BOLD=$(tput bold 2>/dev/null || true); RESET=$(tput sgr0 2>/dev/null || true)
say()  { echo "${BOLD}> $*${RESET}"; }
ok()   { echo "  ok $*"; }
warn() { echo "  ! $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

APPDIR="$HOME/.cato/app"
MODELDIR="$HOME/.cato/models"
TURBO_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
OS="$(uname)"
# Voice/memory models (~2GB) are OFF by default — voice ships later, so a fresh install stays light.
# Opt in now with CATO_WITH_MODELS=1, or fetch them anytime via `skyhelm setup`.
if [ -n "${CATO_WITH_MODELS:-}" ]; then SKIP_MODELS=""; else SKIP_MODELS="1"; fi
[ -n "${CATO_SKIP_MODELS:-}" ] && SKIP_MODELS="1"   # explicit skip (brew) still wins

# Install a system package with whatever package manager is present.
pkg() { # pkg <command> [brew-name]
  local cmd="$1" brewname="${2:-$1}"
  if have "$cmd"; then ok "$cmd present"; return; fi
  echo "  installing $cmd..."
  if have brew;       then brew install "$brewname"
  elif have apt-get;  then sudo apt-get update -qq && sudo apt-get install -y "$cmd"
  elif have dnf;      then sudo dnf install -y "$cmd"
  elif have pacman;   then sudo pacman -S --noconfirm "$cmd"
  else warn "couldn't auto-install $cmd — install it manually"; fi
}

TOTAL=8

# ── 1. Prerequisites: Node >=20 ────────────────────────────────────────────────────────────────
say "1/$TOTAL  Checking prerequisites ($OS)"
have node || { echo "  Node.js >=20 required — install it from https://nodejs.org"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [ "${NODE_MAJOR:-0}" -lt 20 ]; then
  echo "  Node.js >=20 required (found $(node -v)) — update from https://nodejs.org"; exit 1
fi
ok "node $(node -v)"
have curl || { echo "  curl is required to download Skyhelm"; exit 1; }
if have claude || have codex; then
  have claude && ok "claude-cli found"; have codex && ok "codex-cli found"
else
  warn "No coding agent yet. Install one: claude (docs.claude.com/claude-code) or codex (npm i -g @openai/codex)"
fi

# ── 2. Download the release tarball ────────────────────────────────────────────────────────────
say "2/$TOTAL  Downloading Skyhelm ($CATO_DIST)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cato-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
TARBALL="$TMP/skyhelm.tar.gz"
if ! curl -fL --retry 3 -o "$TARBALL" "$CATO_DIST"; then
  echo "  ✗ download failed: $CATO_DIST"; exit 1
fi
ok "downloaded ($(du -h "$TARBALL" | cut -f1 | tr -d ' '))"

# ── 3. Extract to ~/.cato/app (replacing any prior install; DB in ~/.cato/db is untouched) ─────
say "3/$TOTAL  Installing into $APPDIR"
mkdir -p "$HOME/.cato"
if [ -d "$APPDIR" ]; then
  rm -rf "$APPDIR.prev"
  mv "$APPDIR" "$APPDIR.prev"
  warn "backed up previous install → $APPDIR.prev"
fi
mkdir -p "$APPDIR"
# The tarball's top dir is `cato/`; strip it so contents land directly in $APPDIR.
if ! tar -xzf "$TARBALL" -C "$APPDIR" --strip-components=1; then
  echo "  ✗ extract failed"; [ -d "$APPDIR.prev" ] && { rm -rf "$APPDIR"; mv "$APPDIR.prev" "$APPDIR"; warn "restored previous install"; }; exit 1
fi
[ -f "$APPDIR/packages/desktop-agent/package.json" ] || { echo "  ✗ tarball layout unexpected"; exit 1; }
ok "extracted"

# ── 4. System deps (tmux, ffmpeg) ──────────────────────────────────────────────────────────────
say "4/$TOTAL  Installing CLI dependencies (tmux, ffmpeg)"
pkg tmux
pkg ffmpeg
[ "$OS" != "Darwin" ] && ! have tmux && warn "tmux is required to capture agents"

# ── 5. whisper.cpp + Ollama (best-effort; skippable) ───────────────────────────────────────────
if [ -n "$SKIP_MODELS" ]; then
  say "5/$TOTAL  Skipping whisper.cpp + Ollama (voice ships later — 'skyhelm setup' or CATO_WITH_MODELS=1 to add)"
else
  say "5/$TOTAL  Installing whisper.cpp + Ollama (speech-to-text + embeddings)"
  if have whisper-cli || have whisper-server; then ok "whisper.cpp present"
  elif have brew; then brew install whisper-cpp
  else warn "whisper.cpp not auto-installable here — voice STT is off until you build it (github.com/ggerganov/whisper.cpp). Typed commands still work."
  fi
  if ! have ollama; then
    if have brew; then brew install ollama
    elif [ "$OS" = "Linux" ]; then curl -fsSL https://ollama.com/install.sh | sh
    else warn "install Ollama from https://ollama.com"; fi
  fi
fi

# ── 6. Production JS deps (prebuilt — no compile step) ──────────────────────────────────────────
say "6/$TOTAL  Installing JS dependencies (prod only, embedded DB, no Docker)"
(
  cd "$APPDIR"
  if npm ci --omit=dev >/dev/null 2>&1; then ok "npm ci --omit=dev"
  elif npm install --omit=dev >/dev/null 2>&1; then ok "npm install --omit=dev (ci fallback)"
  else echo "  ✗ dependency install failed — run 'cd $APPDIR && npm ci --omit=dev' to see errors"; exit 1; fi
) || exit 1

# ── 7. Models (whisper large-v3-turbo + ollama bge-m3/gemma3:4b) — skippable ───────────────────
if [ -n "$SKIP_MODELS" ]; then
  say "7/$TOTAL  Skipping model downloads (voice ships later — kept light)"
  warn "voice + memory models not fetched (~2GB) — add them anytime: 'skyhelm setup' or re-run with CATO_WITH_MODELS=1"
else
  say "7/$TOTAL  Downloading models (whisper large-v3-turbo ~1.5GB + ollama bge-m3, gemma3:4b)"
  mkdir -p "$MODELDIR"
  if [ -f "$MODELDIR/ggml-large-v3-turbo.bin" ]; then ok "whisper turbo present"
  else curl -L --fail -o "$MODELDIR/ggml-large-v3-turbo.bin" "$TURBO_URL" || warn "whisper model download failed — re-run later"; fi
  if have ollama; then
    curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1 || { ollama serve >/tmp/cato-ollama.log 2>&1 & sleep 2; }
    for m in bge-m3 gemma3:4b; do
      if ollama list 2>/dev/null | grep -q "$m"; then ok "$m present"; else echo "  pulling $m..."; ollama pull "$m"; fi
    done
  else
    warn "ollama not installed — memory/embeddings off until you install it (https://ollama.com)"
  fi
fi

# ── 8. Link `skyhelm` onto PATH ─────────────────────────────────────────────────────────────────
say "8/$TOTAL  Linking 'skyhelm'"
DEST="$HOME/.local/bin"; mkdir -p "$DEST"
ln -sf "$APPDIR/bin/cato" "$DEST/skyhelm"
chmod +x "$APPDIR/bin/cato" 2>/dev/null || true
ok "linked $DEST/skyhelm"
case ":$PATH:" in *":$DEST:"*) : ;; *) warn "Add to your shell rc:  export PATH=\"\$HOME/.local/bin:\$PATH\"";; esac

# Onboard if we're on a real terminal; otherwise nudge the user.
if [ -t 0 ]; then
  echo; node "$APPDIR/bin/cato-setup.mjs" || warn "run 'skyhelm setup' later"
else
  warn "piped install — run 'skyhelm setup' in your terminal to choose your workspace + get your pairing token"
fi

echo
echo "${BOLD}Done. Skyhelm is installed — no Docker, embedded database.${RESET}"
echo "  Set up / re-run:  skyhelm setup       (workspace folder + pairing token"
[ -n "$SKIP_MODELS" ] && echo "                                     + downloads voice/memory models)"
echo "  Pair your phone:  open the Skyhelm app on the same Wi-Fi (it auto-discovers this desktop)"
echo "  Always-on:        skyhelm start        (auto-start the agent)   ·   skyhelm stop"
echo "  Update:           skyhelm update"
