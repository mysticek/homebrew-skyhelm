cask "skyhelm" do
  version "0.2.0"
  sha256 "29f3f07f94bc9ca34300e89053268089114c038cd931a9f344ac49ea4e60e150"

  url "https://github.com/mysticek/homebrew-skyhelm/releases/download/v#{version}/Skyhelm.zip"
  name "Skyhelm"
  desc "Command your AI coding agents from your phone"
  homepage "https://skyhelm.dev"

  #  already means "that version or newer" for a cask. The ">= :ventura" string form
  # means the same thing and is deprecated, which brew says out loud to anyone who runs 158 kegs, 242,396 files, 13.4GB.
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
  # keys. Removing an app should not destroy the work it was used for, so this runs solely on the explicit
  # `brew uninstall --zap skyhelm`.
  zap trash: [
    "~/.skyhelm",
    "~/Library/LaunchAgents/dev.skyhelm.agent.plist",
    "~/Library/LaunchAgents/dev.skyhelm.healthcheck.plist",
    "~/Library/LaunchAgents/dev.skyhelm.app.plist",
  ]
end
