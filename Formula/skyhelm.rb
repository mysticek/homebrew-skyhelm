# Homebrew formula for Skyhelm — command center for AI coding agents.
#
# Ships a prebuilt, source-free tarball (the source repo is private). Brew fetches the tarball,
# installs production node_modules with `npm ci --omit=dev`, and exposes the `skyhelm` CLI. The big
# STT/embedding models are NOT downloaded at install time (kept fast) — the user runs `skyhelm setup`.
#
# Tap + install:
#   brew tap mysticek/skyhelm
#   brew install skyhelm
class Skyhelm < Formula
  desc "Command center for AI coding agents (Claude Code, Codex)"
  homepage "https://skyhelm.dev"
  url "https://github.com/mysticek/homebrew-skyhelm/releases/download/v0.1.44/skyhelm.tar.gz"
  sha256 "0076eb1bab753a8b0b5aa3fd49d08fb761d6343d4d36ae211577f8be283d7145"
  license :cannot_represent # proprietary — desktop agent ships as compiled JS, source is private
  version "0.1.44"

  depends_on "node"
  depends_on "tmux"
  depends_on "ffmpeg"

  def install
    # Brew extracts the tarball and chdirs into its single top-level dir (`cato/`, the internal
    # staging name). Install production dependencies only; @cato/shared resolves as a local workspace.
    ENV["CATO_SKIP_MODELS"] = "1"
    system "npm", "ci", "--omit=dev"

    # Stage the whole runtime tree into libexec, then expose the CLI on PATH with node available.
    # The command is `skyhelm`; the internal launcher file stays bin/cato.
    libexec.install Dir["*"]
    (bin/"skyhelm").write_env_script libexec/"bin/cato",
                                     PATH: "#{Formula["node"].opt_bin}:$PATH"
  end

  def caveats
    <<~EOS
      Finish setup (interactive) — choose a workspace and pair your phone:
        skyhelm setup

      Local memory (semantic search) is optional and needs Ollama:
        brew install ollama

      No Docker and no database server — Skyhelm's database is embedded (PGlite).
    EOS
  end

  test do
    assert_match "0.1.11", shell_output("#{bin}/skyhelm --version")
  end
end
