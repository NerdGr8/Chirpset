import Foundation
import IOKit
import IOKit.serial
import IOKit.usb

/// Watches IOKit for serial/USB devices: identifies them by VID/PID against the
/// board catalog, drains already-connected devices at launch, and fires
/// connect/disconnect callbacks on hotplug. Covers kIOSerialBSDServiceValue
/// services; VolumeMonitor handles mass-storage bootloader volumes.
final class DeviceMonitor {

    /// Called on the main thread whenever a serial device appears.
    var onConnect: ((DetectedDevice) -> Void)?
    /// Called on the main thread whenever a serial device is removed (by id).
    var onDisconnect: ((String) -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0

    /// Maps an IOKit registry-entry id → the device key we published, so we can
    /// resolve which device left when a termination only gives us the io_object.
    private var entryIDToKey: [UInt64: String] = [:]

    func start() {
        let port = IONotificationPortCreate(kIOMainPortDefault)
        guard let port else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, .main)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Matched (appeared)
        let matching = IOServiceMatching(kIOSerialBSDServiceValue)
        IOServiceAddMatchingNotification(
            port, kIOMatchedNotification, matching,
            { refcon, iterator in
                let monitor = Unmanaged<DeviceMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handleMatched(iterator)
            },
            selfPtr, &matchedIterator
        )
        // Drain initial iterator so already-connected devices appear at launch.
        handleMatched(matchedIterator)

        // Terminated (removed)
        let matchingTerm = IOServiceMatching(kIOSerialBSDServiceValue)
        IOServiceAddMatchingNotification(
            port, kIOTerminatedNotification, matchingTerm,
            { refcon, iterator in
                let monitor = Unmanaged<DeviceMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handleTerminated(iterator)
            },
            selfPtr, &terminatedIterator
        )
        handleTerminated(terminatedIterator)
    }

    func stop() {
        if matchedIterator != 0 { IOObjectRelease(matchedIterator); matchedIterator = 0 }
        if terminatedIterator != 0 { IOObjectRelease(terminatedIterator); terminatedIterator = 0 }
        if let notifyPort { IONotificationPortDestroy(notifyPort) }
        notifyPort = nil
    }

    deinit { stop() }

    // MARK: - Iterator handling

    private func handleMatched(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let device = buildDevice(from: service) {
                onConnect?(device)
            }
        }
    }

    private func handleTerminated(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var entryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(service, &entryID)
            if let key = entryIDToKey.removeValue(forKey: entryID) {
                onDisconnect?(key)
            }
        }
    }

    // MARK: - Property extraction

    private func buildDevice(from service: io_object_t) -> DetectedDevice? {
        let callout = stringProp(service, kIOCalloutDeviceKey)
        let vid = numberProp(service, "idVendor").map { UInt16(truncatingIfNeeded: $0) }
        let pid = numberProp(service, "idProduct").map { UInt16(truncatingIfNeeded: $0) }
        let serial = stringProp(service, "USB Serial Number")
        let product = stringProp(service, "USB Product Name")
        let vendor = stringProp(service, "USB Vendor Name")

        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)

        // Stable key: prefer serial number, else callout path, else registry id.
        let key = serial ?? callout ?? "io:\(entryID)"

        var matchedBoard: BoardDefinition?
        var isBootloader = false
        if let vid, let pid, let m = BoardCatalog.match(vid: vid, pid: pid) {
            matchedBoard = m.board
            isBootloader = m.isBootloader
        }

        entryIDToKey[entryID] = key

        return DetectedDevice(
            id: key,
            board: matchedBoard,
            vid: vid, pid: pid,
            serialNumber: serial,
            manufacturer: vendor,
            productName: product,
            calloutPath: callout,
            volumePath: nil,
            status: isBootloader ? .bootloader : .connected,
            detectedInBootloader: isBootloader
        )
    }

    // MARK: - IORegistry helpers

    /// Search the service and its USB ancestors for a string property.
    private func stringProp(_ service: io_object_t, _ key: String) -> String? {
        let opts = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        guard let cf = IORegistryEntrySearchCFProperty(
            service, kIOServicePlane, key as CFString, kCFAllocatorDefault, opts
        ) else { return nil }
        return (cf as? String)
    }

    private func numberProp(_ service: io_object_t, _ key: String) -> Int? {
        let opts = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        guard let cf = IORegistryEntrySearchCFProperty(
            service, kIOServicePlane, key as CFString, kCFAllocatorDefault, opts
        ) else { return nil }
        return (cf as? NSNumber)?.intValue
    }
}
