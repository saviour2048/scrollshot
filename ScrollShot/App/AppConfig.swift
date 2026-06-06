import Foundation

/// App-wide constants and small helpers.
enum AppConfig {
    static let appName = "ScrollShot"

    /// Minimum drag size (in points) that counts as a valid region selection.
    static let minimumSelectionSize: CGFloat = 8

    /// Default directory offered by the save panel (~/Pictures, falling back to home).
    static var defaultSaveDirectory: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    /// Timestamped default file name, e.g. `ScrollShot-20260606-153012.png`.
    static func defaultFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(appName)-\(formatter.string(from: date)).png"
    }

    /// Deep link to System Settings ▸ Privacy & Security ▸ Screen Recording.
    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )
}
