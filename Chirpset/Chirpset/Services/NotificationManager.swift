import Foundation
import UserNotifications

/// Which device events should fire a system notification.
enum NotificationLevel: String, CaseIterable, Identifiable {
    case all
    case connectOnly
    case bootloaderOnly
    case off

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all:            return "All events"
        case .connectOnly:    return "Connect / disconnect only"
        case .bootloaderOnly: return "Bootloader mode only"
        case .off:            return "Off"
        }
    }
}

enum DeviceEvent {
    case connected
    case disconnected
    case bootloader
    case flashComplete
    case flashFailed
}

/// Wraps UNUserNotificationCenter and applies the user's notification level.
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    private var authorized = false

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            self.authorized = granted
        }
    }

    func notify(_ event: DeviceEvent, deviceName: String, detail: String, level: NotificationLevel) {
        guard shouldFire(event, level: level) else { return }

        let content = UNMutableNotificationContent()
        let (title, body) = copy(for: event, deviceName: deviceName, detail: detail)
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func shouldFire(_ event: DeviceEvent, level: NotificationLevel) -> Bool {
        switch level {
        case .off:
            return false
        case .all:
            return true
        case .connectOnly:
            return event == .connected || event == .disconnected
        case .bootloaderOnly:
            return event == .bootloader
        }
    }

    private func copy(for event: DeviceEvent, deviceName: String, detail: String) -> (String, String) {
        switch event {
        case .connected:     return ("\(deviceName) connected", detail)
        case .disconnected:  return ("Device disconnected", "\(deviceName) removed")
        case .bootloader:    return ("\(deviceName) in bootloader mode", "Ready to flash — \(detail)")
        case .flashComplete: return ("Flash complete", "\(deviceName) — firmware written successfully")
        case .flashFailed:   return ("Flash failed", "\(deviceName) — \(detail)")
        }
    }
}
