# Homebrew cask for Skyhelm — the macOS distribution.
#
# WHY A CASK AND NOT THE FORMULA: macOS ties Local Network and Files grants to a program's code
# identity. The formula installs plain JS run by Homebrew's node, which is ad-hoc signed with no Team
# ID — so there is nothing stable to grant to, the permission prompt returns after every upgrade, and
# System Settings lists "node" instead of Skyhelm. Skyhelm.app is signed with our Developer ID and
# notarized, so the grant is made once and survives. The formula is Linux-only from now on.
#
# The bundle carries everything: the menu bar app (Contents/MacOS/Skyhelm), its own Node runtime
# (Contents/Resources/node) and the agent + CLI (Contents/Resources/agent). Nothing is resolved from
# the user's machine, which is what keeps the identity — and therefore the grant — stable.
#
#   brew tap mysticek/skyhelm
#   brew install --cask skyhelm
cask "skyhelm" do
  version "0.3.2"
  sha256 "77639080bdc2b8a64d92a3ef027448f9b7b82f30c4fcb18a384749568a184f87"

  url "https://github.com/mysticek/homebrew-skyhelm/releases/download/v#{version}/Skyhelm.zip"
  name "Skyhelm"
  desc "Command center for AI coding agents (Claude Code, Codex)"
  homepage "https://skyhelm.dev"

  # LSMinimumSystemVersion in the bundle; MenuBarExtra needs 13 too.
  depends_on macos: ">= :ventura"
  # tmux and ffmpeg stay external: they're user-facing tools the agent shells out to, not runtime
  # libraries, and vendoring them into the bundle would mean signing and notarizing someone else's
  # binaries on every release.
  depends_on formula: "tmux"
  depends_on formula: "ffmpeg"

  app "Skyhelm.app"
  # The CLI lives inside the bundle, so `skyhelm` on PATH and the daemon are the same build — the
  # split-brain we'd get from a separately-installed CLI is exactly what this layout removes.
  binary "#{appdir}/Skyhelm.app/Contents/Resources/agent/bin/skyhelm"

  postflight do
    # Point the LaunchAgent at the bundle and start it. Skyhelm is an always-on watcher: an install
    # that doesn't run until you remember to open something isn't the product.
    # Through bash, with a PATH: brew runs postflight commands with a minimal environment, and the
    # script needs `node` (Homebrew's, or the bundle's) to read the config it arms launchd with.
    # Invoked directly it exits non-zero, and because a postflight may not fail an install it does so
    # in silence — which is exactly how a machine ends up with the app installed and no agent behind
    # it. Verified: the same command by hand, with a PATH, arms all three jobs.
    system_command "/bin/bash",
                   args: ["-lc",
                          "PATH=/opt/homebrew/bin:/usr/local/bin:$PATH " \
                          "bash '#{appdir}/Skyhelm.app/Contents/Resources/agent/bin/skyhelm-daemon.sh' on"],
                   must_succeed: false
    # …and bring the menu bar back. On an UPGRADE brew runs the old cask's uninstall stanza first,
    # which quits the app — without this the icon simply vanishes until the next login, and the user
    # is left believing the update broke Skyhelm.
    system_command "/usr/bin/open", args: ["-a", "#{appdir}/Skyhelm.app"], must_succeed: false
  end

  uninstall launchctl: [
              "dev.skyhelm.agent",
              "dev.skyhelm.healthcheck",
            ],
            quit:      "app.skyhelm"

  # ~/.skyhelm holds the user's own data — sessions, journal, keys, the embedded database. It goes
  # only on `brew uninstall --zap`, never on a plain uninstall or an upgrade.
  zap trash: [
    "~/.skyhelm",
    "~/Library/LaunchAgents/dev.skyhelm.agent.plist",
    "~/Library/LaunchAgents/dev.skyhelm.healthcheck.plist",
  ]

  caveats <<~EOS
    Skyhelm runs in the menu bar and watches the Claude Code / Codex sessions on this Mac.

    Pair your phone:
      skyhelm pair

    macOS will ask once for Local Network access — that's how the phone reaches this Mac
    directly on your Wi-Fi, without anything going through the internet.
  EOS
end
