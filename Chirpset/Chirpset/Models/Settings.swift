import Foundation
import ServiceManagement

/// User preferences, persisted to UserDefaults.
final class Preferences: ObservableObject {

    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(); persist(\.launchAtLogin, launchAtLogin) }
    }
    @Published var autoReconnectSerial: Bool {
        didSet { persist(\.autoReconnectSerial, autoReconnectSerial) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { persist(\.notificationsEnabled, notificationsEnabled) }
    }
    @Published var bootloaderAlerts: Bool {
        didSet { persist(\.bootloaderAlerts, bootloaderAlerts) }
    }
    @Published var notificationLevelRaw: String {
        didSet { persist(\.notificationLevelRaw, notificationLevelRaw) }
    }
    @Published var soundEnabled: Bool {
        didSet { persist(\.soundEnabled, soundEnabled) }
    }
    @Published var hideBuiltInDevices: Bool {
        didSet { persist(\.hideBuiltInDevices, hideBuiltInDevices) }
    }

    var effectiveLevel: NotificationLevel {
        guard notificationsEnabled else { return .off }
        return NotificationLevel(rawValue: notificationLevelRaw) ?? .all
    }

    private let defaults = UserDefaults.standard

    init() {
        launchAtLogin       = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        autoReconnectSerial = defaults.object(forKey: "autoReconnectSerial") as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        bootloaderAlerts    = defaults.object(forKey: "bootloaderAlerts") as? Bool ?? true
        notificationLevelRaw = defaults.string(forKey: "notificationLevelRaw") ?? NotificationLevel.all.rawValue
        soundEnabled        = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        hideBuiltInDevices  = defaults.object(forKey: "hideBuiltInDevices") as? Bool ?? true
    }

    private func persist<T>(_ key: ReferenceWritableKeyPath<Preferences, T>, _ value: T) {
        let name: String
        switch key {
        case \Preferences.launchAtLogin:        name = "launchAtLogin"
        case \Preferences.autoReconnectSerial:  name = "autoReconnectSerial"
        case \Preferences.notificationsEnabled: name = "notificationsEnabled"
        case \Preferences.bootloaderAlerts:     name = "bootloaderAlerts"
        case \Preferences.notificationLevelRaw: name = "notificationLevelRaw"
        case \Preferences.soundEnabled:         name = "soundEnabled"
        case \Preferences.hideBuiltInDevices:   name = "hideBuiltInDevices"
        default: return
        }
        defaults.set(value, forKey: name)
    }

    private func applyLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            // Non-fatal: surface in logs only.
            NSLog("Chirpset: launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
