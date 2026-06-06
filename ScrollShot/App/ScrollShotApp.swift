import SwiftUI
import AppKit

@main
struct ScrollShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = CaptureSession()

    var body: some Scene {
        WindowGroup(AppConfig.appName) {
            MainView()
                .environmentObject(session)
                .frame(minWidth: 480, minHeight: 380)
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
