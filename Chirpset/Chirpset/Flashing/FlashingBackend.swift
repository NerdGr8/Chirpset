import Foundation

/// Flashing isn't one operation: each backend handles a different mechanism,
/// dispatched by USB VID/PID.
protocol FlashingBackend {
    /// Whether this backend can flash the given device.
    func canHandle(_ device: DetectedDevice) -> Bool

    /// Flash `firmware` to `device`, reporting (fraction 0…1, status line).
    /// Throws `FlashError` on failure.
    func flash(firmware: URL,
               to device: DetectedDevice,
               progress: @escaping (Double, String) -> Void) async throws

    /// Whether this backend can read (clone) the device's firmware back out.
    func canClone(_ device: DetectedDevice) -> Bool

    /// Read the device's firmware into `destination`, reporting progress.
    func cloneFirmware(from device: DetectedDevice,
                       to destination: URL,
                       progress: @escaping (Double, String) -> Void) async throws

    /// The file extension a clone of this device should use (e.g. "bin", "hex").
    func cloneFileExtension(for device: DetectedDevice) -> String
}

extension FlashingBackend {
    func canClone(_ device: DetectedDevice) -> Bool { false }
    func cloneFirmware(from device: DetectedDevice,
                       to destination: URL,
                       progress: @escaping (Double, String) -> Void) async throws {
        throw FlashError.cloneUnsupported
    }
    func cloneFileExtension(for device: DetectedDevice) -> String { "bin" }
}

enum FlashError: LocalizedError {
    case unsupportedDevice
    case deviceNotInFlashableState
    case missingVolume(String)
    case badFirmware(String)
    case toolNotBundled(String)
    case toolFailed(code: Int32, message: String)
    case cloneUnsupported
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "This device family isn't supported for flashing yet."
        case .deviceNotInFlashableState:
            return "Put the device in bootloader mode first."
        case .missingVolume(let v):
            return "Bootloader volume \(v) is no longer mounted."
        case .badFirmware(let m):
            return "Firmware file problem: \(m)"
        case .toolNotBundled(let t):
            return "Couldn't find \(t). It isn't bundled yet — install it (e.g. brew install \(t)) and try again."
        case .toolFailed(let code, let message):
            return "Flashing tool exited with code \(code): \(message)"
        case .cloneUnsupported:
            return "Cloning isn't supported for this board family yet."
        case .cancelled:
            return "Flashing cancelled."
        }
    }
}
