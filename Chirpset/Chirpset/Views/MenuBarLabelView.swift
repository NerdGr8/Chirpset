import SwiftUI

/// The menu bar status item's label. Wrapping the icon in a view (rather than a
/// bare `Image`) gives us an `onAppear` that fires at launch — the reliable point
/// to capture `openWindow` so the Dock-icon reopen handler can open Settings.
struct MenuBarLabelView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: MenuBarIcon.image)
            .onAppear {
                let action = {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                app.openSettingsWindow = action
                AppDelegate.onReopen = action
            }
    }
}
