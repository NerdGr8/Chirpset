import Foundation
import AppKit

/// Watches volume mount/unmount events to spot mass-storage bootloader devices:
/// Pico as RPI-RP2, micro:bit as MAINTENANCE, SAMD boards as a bootloader drive.
final class VolumeMonitor {

    /// A recognized bootloader volume mounted. Provides the device + its path.
    var onBootloaderVolumeMounted: ((DetectedDevice) -> Void)?
    /// A previously-seen bootloader volume unmounted (by device id == volume path).
    var onBootloaderVolumeUnmounted: ((String) -> Void)?

    private var knownVolumeKeys: Set<String> = []

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(didMount(_:)),
                       name: NSWorkspace.didMountNotification, object: nil)
        nc.addObserver(self, selector: #selector(didUnmount(_:)),
                       name: NSWorkspace.didUnmountNotification, object: nil)
        scanExisting()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    deinit { stop() }

    private func scanExisting() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey]
        let mounted = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: []) ?? []
        for url in mounted { evaluate(url) }
    }

    @objc private func didMount(_ note: Notification) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        evaluate(url)
    }

    @objc private func didUnmount(_ note: Notification) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        let key = url.path
        if knownVolumeKeys.remove(key) != nil {
            onBootloaderVolumeUnmounted?(key)
        }
    }

    private func evaluate(_ url: URL) {
        let name = volumeName(url)
        guard let name, let board = BoardCatalog.match(volumeName: name) else { return }
        let key = url.path
        guard !knownVolumeKeys.contains(key) else { return }
        knownVolumeKeys.insert(key)

        let device = DetectedDevice(
            id: key,
            board: board,
            vid: board.bootloaderVID, pid: board.bootloaderPID,
            serialNumber: nil,
            manufacturer: board.manufacturer,
            productName: board.displayName,
            calloutPath: nil,
            volumePath: url.path,
            status: .bootloader,
            detectedInBootloader: true
        )
        onBootloaderVolumeMounted?(device)
    }

    private func volumeName(_ url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName
    }
}
