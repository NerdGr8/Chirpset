import SwiftUI

/// Settings window with General / Notifications / Tools tabs (mirrors prototype).
struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var tab: Tab = .general

    enum Tab: String, CaseIterable, Identifiable {
        case general, notifications, tools
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "General"
            case .notifications: return "Notifications"
            case .tools: return "Tools"
            }
        }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .notifications: return "bell"
            case .tools: return "wrench.and.screwdriver"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(Theme.borderLight)
            ScrollView { content.padding(20) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 560, height: 420)
        .background(Theme.bg)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon).font(.system(size: 12)).frame(width: 16)
                        Text(t.title).font(Theme.body(12))
                        Spacer()
                    }
                    .foregroundStyle(tab == t ? Theme.fg : Theme.fgSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(tab == t ? Color.white.opacity(0.07) : .clear,
                                in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 140)
        .background(Color.white.opacity(0.02))
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general:       general
        case .notifications: notifications
        case .tools:         tools
        }
    }

    // MARK: General

    private var general: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("General")
            toggleRow("Launch at login",
                      "Start Chirpset automatically when you log in",
                      isOn: Binding(get: { app.prefs.launchAtLogin },
                                    set: { app.prefs.launchAtLogin = $0 }))
            toggleRow("Auto-reconnect serial",
                      "Reopen serial monitor when a known device is plugged back in",
                      isOn: Binding(get: { app.prefs.autoReconnectSerial },
                                    set: { app.prefs.autoReconnectSerial = $0 }))
            toggleRow("Chirp on connect / disconnect",
                      "Play Chirpset's chirp when a device is plugged in or removed",
                      isOn: Binding(get: { app.prefs.soundEnabled },
                                    set: { app.prefs.soundEnabled = $0
                                           if $0 { app.previewChirp() } }))
            toggleRow("Hide built-in serial devices",
                      "Hide macOS's default ports (Bluetooth, debug consoles) from the list",
                      isOn: Binding(get: { app.prefs.hideBuiltInDevices },
                                    set: { app.prefs.hideBuiltInDevices = $0 }))
        }
    }

    // MARK: Notifications

    private var notifications: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Notifications")
            toggleRow("Enable notifications",
                      "Show system notifications for device events",
                      isOn: Binding(get: { app.prefs.notificationsEnabled },
                                    set: { app.prefs.notificationsEnabled = $0 }))
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Notification level").font(Theme.body(12)).foregroundStyle(Theme.fgSecondary)
                    Text("Choose which events trigger notifications")
                        .font(Theme.body(10)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Picker("", selection: Binding(get: { app.prefs.notificationLevelRaw },
                                              set: { app.prefs.notificationLevelRaw = $0 })) {
                    ForEach(NotificationLevel.allCases.filter { $0 != .off }) {
                        Text($0.title).tag($0.rawValue)
                    }
                }
                .labelsHidden().frame(width: 200)
            }
            .padding(.vertical, 8)
            .overlay(Divider().overlay(Theme.borderLight), alignment: .bottom)

            toggleRow("Bootloader-mode alerts",
                      "Distinct notification when a device enters flashable state",
                      isOn: Binding(get: { app.prefs.bootloaderAlerts },
                                    set: { app.prefs.bootloaderAlerts = $0 }))
        }
    }

    // MARK: Tools

    private var tools: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Flashing Tools")
            Text("Tools ship bundled in the app. When a tool isn't bundled yet, Chirpset falls back to a system install (Homebrew, pip, Arduino IDE) if it can find one.")
                .font(Theme.body(10)).foregroundStyle(Theme.muted)
                .padding(.bottom, 8)
            nativeToolRow("UF2 copy", "Pico / RP2040")
            toolRow("esptool", "ESP32 / ESP8266")
            toolRow("avrdude", "Arduino AVR")
            toolRow("bossac", "Arduino SAMD")
            toolRow("dfu-util", "STM32")
            toolRow("teensy_loader_cli", "Teensy")
        }
    }

    // MARK: Pieces

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.fg)
            .padding(.bottom, 12)
    }

    private func toggleRow(_ title: String, _ desc: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.body(12)).foregroundStyle(Theme.fgSecondary)
                Text(desc).font(Theme.body(10)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(Theme.accent)
        }
        .padding(.vertical, 8)
        .overlay(Divider().overlay(Theme.borderLight), alignment: .bottom)
    }

    private func toolRow(_ name: String, _ family: String) -> some View {
        let source = ToolLocator.locate(name)
        let (status, color): (String, Color) = {
            switch source {
            case .bundled: return ("Bundled", Theme.accent)
            case .system:  return ("System", Theme.accentBlue)
            case nil:      return ("Not found", Theme.muted)
            }
        }()
        return HStack {
            Text(name).font(Theme.mono(11)).foregroundStyle(Theme.fgSecondary)
            Text(family).font(Theme.body(10)).foregroundStyle(Theme.muted)
            Spacer()
            Text(status).font(Theme.body(10)).foregroundStyle(color)
        }
        .padding(.vertical, 6)
        .overlay(Divider().overlay(Theme.borderLight), alignment: .bottom)
    }

    private func nativeToolRow(_ name: String, _ family: String) -> some View {
        HStack {
            Text(name).font(Theme.mono(11)).foregroundStyle(Theme.fgSecondary)
            Text(family).font(Theme.body(10)).foregroundStyle(Theme.muted)
            Spacer()
            Text("Native").font(Theme.body(10)).foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 6)
        .overlay(Divider().overlay(Theme.borderLight), alignment: .bottom)
    }
}
