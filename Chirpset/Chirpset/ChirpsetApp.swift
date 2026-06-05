import SwiftUI

@main
struct ChirpsetApp: App {
    @StateObject private var app = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(app)
                .onAppear { app.start() }
        } label: {
            MenuBarLabelView().environmentObject(app)
        }
        .menuBarExtraStyle(.window)

        // Settings window.
        Window("Chirpset Settings", id: "settings") {
            SettingsView().environmentObject(app)
        }
        .windowResizability(.contentSize)

        // Firmware Library window.
        Window("Firmware Library", id: "library") {
            FirmwareLibraryView(library: app.library).environmentObject(app)
        }
        .windowResizability(.contentSize)

        // Serial monitor — one window per device id.
        WindowGroup(id: "serial", for: String.self) { $deviceID in
            if let deviceID {
                SerialMonitorView(deviceID: deviceID).environmentObject(app)
            }
        }
        .windowResizability(.contentMinSize)
    }
}

/// Opens Settings when the Dock icon is clicked and no windows are open. The
/// action is supplied by MenuBarLabelView once SwiftUI's openWindow exists.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var onReopen: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { AppDelegate.onReopen?() }
        return true
    }
}
