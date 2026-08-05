cask "skyhelm" do
  version "0.3.0"
  sha256 "1bf6c252b4ff461dac8a17e68f2310a94545f9704e69f9e9e56c90e3881a27f9"

  url "https://github.com/mysticek/homebrew-skyhelm/releases/download/v#{version}/Skyhelm.zip"
  name "Skyhelm"
  desc "Command your AI coding agents from your phone"
  homepage "https://skyhelm.dev"

  # :ventura already means "that version or newer" for a cask. The ">= :ventura" string form means the
  # same thing and is deprecated, which brew announces to anyone who runs brew info.
  depends_on macos: :ventura

  app "Skyhelm.app"

  # The daemon and its watchdog are launchd agents, so an uninstall has to unload them. Without this they
  # keep running — and the watchdog's whole purpose is to bring back an agent that has gone away, which
  # after an uninstall means resurrecting a binary that is no longer there.
  uninstall launchctl: [
              "dev.skyhelm.agent",
              "dev.skyhelm.healthcheck",
              "dev.skyhelm.app",
            ],
            quit:      "app.skyhelm"

  # zap only, never uninstall: ~/.skyhelm holds the session journals, the memory database and the device
  # keys. Removing an app should not destroy the work it was used for, so this runs solely on an explicit
  # brew uninstall --zap.
  zap trash: [
    "~/.skyhelm",
    "~/Library/LaunchAgents/dev.skyhelm.agent.plist",
    "~/Library/LaunchAgents/dev.skyhelm.healthcheck.plist",
    "~/Library/LaunchAgents/dev.skyhelm.app.plist",
  ]
end
