import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct ScrollShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppConfig.appName, systemImage: "camera.viewfinder") {
            Button("截图") {
                CaptureController.shared.trigger()
            }

            Button("滚动截图") {
                ScrollCaptureController.shared.trigger()
            }

            Divider()

            settingsButton

            Button("关于 \(AppConfig.appName)") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }

            Divider()

            Button("退出 \(AppConfig.appName)") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            PreferencesView()
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text("偏好设置…")
            }
        } else {
            Button("偏好设置…") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar background app: no Dock icon, but can still show windows.
        NSApp.setActivationPolicy(.accessory)

        KeyboardShortcuts.onKeyUp(for: .captureRegion) {
            // KeyboardShortcuts invokes handlers on the main thread.
            MainActor.assumeIsolated {
                CaptureController.shared.trigger()
            }
        }
    }
}
