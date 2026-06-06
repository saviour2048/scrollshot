import KeyboardShortcuts

/// Global keyboard-shortcut identifiers. The user can re-record these in
/// Preferences; the chosen key is persisted by the KeyboardShortcuts library.
extension KeyboardShortcuts.Name {
    /// Trigger the Flameshot-style frozen capture overlay.
    static let captureRegion = Self(
        "captureRegion",
        default: .init(.a, modifiers: [.control, .option])
    )
}
