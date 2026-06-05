import SwiftUI

/// Runtime status of a detected device.
enum DeviceStatus: Equatable {
    case connected      // present in run mode
    case bootloader     // detected in a flashable (bootloader/DFU/mass-storage) state
    case flashing       // a flash is in progress
    case cloning        // reading firmware off the device
    case error          // last operation failed
    case disconnected   // removed

    var label: String {
        switch self {
        case .connected:    return "Connected"
        case .bootloader:   return "Bootloader"
        case .flashing:     return "Flashing…"
        case .cloning:      return "Reading…"
        case .error:        return "Error"
        case .disconnected: return "Offline"
        }
    }

    var color: Color {
        switch self {
        case .connected:    return Theme.accent
        case .bootloader:   return Theme.accentAmber
        case .flashing:     return Theme.accentBlue
        case .cloning:      return Theme.accentBlue
        case .error, .disconnected: return Theme.accentRed
        }
    }
}

/// A device discovered by the IOKit serial watcher or the volume watcher.
/// Identity is keyed so the same physical board re-enumerating in bootloader
/// mode (different VID/PID) can be reconciled where possible.
struct DetectedDevice: Identifiable, Equatable {
    let id: String                 // stable key: serial-number, else io-path, else volume path
    var board: BoardDefinition?    // resolved from VID/PID or volume name (nil = unknown)

    var vid: UInt16?
    var pid: UInt16?
    var serialNumber: String?
    var manufacturer: String?
    var productName: String?

    /// `/dev/cu.*` device path for serial devices.
    var calloutPath: String?
    /// `/Volumes/...` path for mass-storage bootloader devices.
    var volumePath: String?

    var status: DeviceStatus
    var detectedInBootloader: Bool = false

    static func == (lhs: DetectedDevice, rhs: DetectedDevice) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status &&
        lhs.calloutPath == rhs.calloutPath && lhs.volumePath == rhs.volumePath
    }

    // MARK: Derived display

    var displayName: String {
        productName ?? board?.displayName ?? "Unknown serial device"
    }

    var manufacturerName: String {
        manufacturer ?? board?.manufacturer ?? "Unknown"
    }

    var vidPidString: String {
        guard let vid, let pid else { return "—" }
        return String(format: "0x%04X:0x%04X", vid, pid)
    }

    var pathDisplay: String {
        calloutPath ?? volumePath ?? "—"
    }

    var isVolumeDevice: Bool { volumePath != nil }

    var backendLabel: String { board?.backendLabel ?? "Unidentified" }

    /// Whether the firmware drag-to-flash zone should be offered.
    var isFlashable: Bool {
        guard let board else { return false }
        if !board.flashSupportedV1 { return false }
        switch board.backend {
        case .massStorage: return status == .bootloader   // needs the volume mounted
        case .serialTool:  return status == .connected || status == .bootloader
        }
    }

    var needsManualBootloaderEntry: Bool {
        guard let board else { return false }
        return !board.entry.isAutomatic && status != .bootloader
    }

    var iconAccent: Color { board?.icon.accent ?? Theme.muted }

    /// macOS exposes built-in serial ports (Bluetooth incoming, debug consoles)
    /// plus RFCOMM ports for paired Bluetooth devices (speakers, soundbars) that
    /// aren't maker hardware. These are the "default devices" users typically
    /// want hidden from the list.
    var isBuiltInSystemDevice: Bool {
        guard let path = calloutPath?.lowercased() else { return false }  // serial ports only
        let markers = ["bluetooth-incoming-port", "debug-console", "wlan-debug", "blth"]
        if markers.contains(where: { path.contains($0) }) { return true }
        // Bluetooth / virtual serial ports carry no USB VID/PID. Any unidentified
        // non-USB serial port is treated as a default/system device. Real boards
        // always enumerate a USB VID/PID, so they're never caught here.
        return vid == nil && board == nil
    }
}
