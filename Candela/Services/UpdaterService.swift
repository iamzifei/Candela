import AppKit
import Sparkle

/// Thin wrapper around Sparkle's standard updater.
///
/// `SPUStandardUpdaterController` owns the whole update experience — the
/// "update available" prompt, the download progress, install-and-relaunch —
/// and runs its background checks from the `SUEnableAutomaticChecks` and
/// `SUScheduledCheckInterval` keys in Info.plist. The feed and the EdDSA public
/// key that authenticates it come from Info.plist as well (`SUFeedURL`,
/// `SUPublicEDKey`), so nothing about the update channel is compiled in here.
///
/// Updating only works from a bundle Sparkle can replace. `dev.sh` swaps a bare
/// binary into an installed app and the probe scripts run unbundled, so when
/// there is no bundle identifier the controller is never started and the menu
/// row disables itself rather than failing at the moment someone clicks it.
@MainActor
final class UpdaterService: ObservableObject {
    static let shared = UpdaterService()

    private let controller: SPUStandardUpdaterController?

    private init() {
        guard Bundle.main.bundleIdentifier != nil else {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Whether a check can start right now — drives the row's enabled state.
    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    /// The version this build reports, shown next to the row so "check for
    /// updates" is answerable even before the check runs.
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// A user-initiated check always shows UI, including "you're up to date",
    /// which is precisely what someone who pressed the button asked to be told.
    /// The scheduled background check stays silent unless there is something to
    /// install.
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
