import Foundation

/// Dispatches a flash request to the correct backend based on the device's
/// board family. Owns the registered backends.
struct FlashCoordinator {

    private let backends: [FlashingBackend] = [
        MassStorageBackend(),
        SerialToolBackend(),
    ]

    func backend(for device: DetectedDevice) -> FlashingBackend? {
        backends.first { $0.canHandle(device) }
    }

    func flash(firmware: URL,
               to device: DetectedDevice,
               progress: @escaping (Double, String) -> Void) async throws {
        guard let backend = backend(for: device) else {
            throw FlashError.unsupportedDevice
        }
        try await backend.flash(firmware: firmware, to: device, progress: progress)
    }

    func canClone(_ device: DetectedDevice) -> Bool {
        backends.contains { $0.canClone(device) }
    }

    func cloneFileExtension(for device: DetectedDevice) -> String {
        backends.first { $0.canClone(device) }?.cloneFileExtension(for: device) ?? "bin"
    }

    func clone(from device: DetectedDevice,
               to destination: URL,
               progress: @escaping (Double, String) -> Void) async throws {
        guard let backend = backends.first(where: { $0.canClone(device) }) else {
            throw FlashError.cloneUnsupported
        }
        try await backend.cloneFirmware(from: device, to: destination, progress: progress)
    }
}
