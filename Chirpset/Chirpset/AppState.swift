import SwiftUI
import Combine

/// In-progress device operation (flash/restore writes, or clone reads).
struct FlashState: Equatable {
    enum Kind: Equatable { case flash, clone }
    enum Phase: Equatable { case running, done, error }
    var deviceID: String
    var kind: Kind = .flash
    var fraction: Double
    var statusText: String
    var phase: Phase
}

/// A transient in-app toast mirroring the system notification.
struct Toast: Identifiable, Equatable {
    enum Kind { case connect, disconnect, bootloader, flashSuccess, flashError, cloneSuccess }
    let id = UUID()
    let kind: Kind
    let title: String
    let text: String
}

/// Central app state: owns the monitors, the device list, flashing, and toasts.
@MainActor
final class AppState: ObservableObject {

    @Published var devices: [DetectedDevice] = []
    @Published var selectedDeviceID: String?
    @Published var flash: FlashState?
    @Published var toasts: [Toast] = []
    @Published var scanning = true

    let prefs = Preferences()
    let library = FirmwareLibrary()

    /// Set by the menu bar label view once `openWindow` is available; lets the
    /// Dock-icon reopen handler surface the Settings window.
    var openSettingsWindow: (() -> Void)?

    private let deviceMonitor = DeviceMonitor()
    private let volumeMonitor = VolumeMonitor()
    private let coordinator = FlashCoordinator()
    private let chirp = ChirpPlayer()
    private var flashTask: Task<Void, Never>?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Re-render the panel when preferences change (e.g. the hide-built-ins
        // toggle), since connectedDevices is derived from prefs.
        prefs.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        library.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var connectedDevices: [DetectedDevice] {
        devices.filter { device in
            guard device.status != .disconnected else { return false }
            if prefs.hideBuiltInDevices && device.isBuiltInSystemDevice { return false }
            return true
        }
    }

    func start() {
        NotificationManager.shared.requestAuthorization()

        deviceMonitor.onConnect = { [weak self] device in
            Task { @MainActor in self?.deviceAppeared(device) }
        }
        deviceMonitor.onDisconnect = { [weak self] id in
            Task { @MainActor in self?.deviceRemoved(id) }
        }
        volumeMonitor.onBootloaderVolumeMounted = { [weak self] device in
            Task { @MainActor in self?.deviceAppeared(device) }
        }
        volumeMonitor.onBootloaderVolumeUnmounted = { [weak self] id in
            Task { @MainActor in self?.deviceRemoved(id) }
        }

        deviceMonitor.start()
        volumeMonitor.start()
    }

    // MARK: - Device lifecycle

    private func deviceAppeared(_ device: DetectedDevice) {
        let event: DeviceEvent = device.detectedInBootloader ? .bootloader : .connected

        let isNew = !devices.contains { $0.id == device.id }
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }

        // Hidden built-in ports are kept in the model (so they reappear if the
        // user unhides them) but generate no chirp/notification/toast.
        if prefs.hideBuiltInDevices && device.isBuiltInSystemDevice { return }

        // Chirp only on a genuinely new arrival, not on a status refresh.
        if isNew, prefs.soundEnabled {
            chirp.play(device.detectedInBootloader ? .bootloader : .connect)
        }

        NotificationManager.shared.notify(
            event, deviceName: device.displayName, detail: device.pathDisplay,
            level: prefs.effectiveLevel)
        pushToast(event == .bootloader
                  ? Toast(kind: .bootloader, title: "\(device.displayName) in bootloader mode",
                          text: "Ready to flash — \(device.pathDisplay)")
                  : Toast(kind: .connect, title: "\(device.displayName) connected",
                          text: device.pathDisplay))
    }

    private func deviceRemoved(_ id: String) {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        let removed = devices[idx]
        let name = removed.displayName

        if flash?.deviceID == id { cancelFlash() }
        if selectedDeviceID == id { selectedDeviceID = nil }
        devices.remove(at: idx)

        // No events for hidden built-in ports.
        if prefs.hideBuiltInDevices && removed.isBuiltInSystemDevice { return }

        if prefs.soundEnabled { chirp.play(.disconnect) }

        NotificationManager.shared.notify(
            .disconnected, deviceName: name, detail: "", level: prefs.effectiveLevel)
        pushToast(Toast(kind: .disconnect, title: "Device disconnected", text: "\(name) removed"))
    }

    func select(_ id: String) {
        selectedDeviceID = (selectedDeviceID == id) ? nil : id
    }

    /// Plays the connect chirp once, e.g. when the user enables sound in settings.
    func previewChirp() { chirp.play(.connect) }

    // MARK: - Flashing

    func beginFlash(deviceID: String, firmware: URL) {
        guard flash == nil, let device = devices.first(where: { $0.id == deviceID }) else { return }
        flash = FlashState(deviceID: deviceID, fraction: 0, statusText: "Preparing…", phase: .running)
        setStatus(deviceID, .flashing)

        flashTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.coordinator.flash(firmware: firmware, to: device) { fraction, text in
                    Task { @MainActor in
                        guard self.flash?.deviceID == deviceID else { return }
                        self.flash?.fraction = fraction
                        self.flash?.statusText = text
                    }
                }
                await self.finishFlash(deviceID: deviceID, device: device, error: nil)
            } catch is CancellationError {
                // already handled by cancelFlash()
            } catch {
                await self.finishFlash(deviceID: deviceID, device: device, error: error)
            }
        }
    }

    private func finishFlash(deviceID: String, device: DetectedDevice, error: Error?) {
        if let error {
            flash?.phase = .error
            flash?.statusText = error.localizedDescription
            setStatus(deviceID, .error)
            NotificationManager.shared.notify(
                .flashFailed, deviceName: device.displayName,
                detail: error.localizedDescription, level: prefs.effectiveLevel)
            pushToast(Toast(kind: .flashError, title: "Flash failed",
                            text: "\(device.displayName) — \(error.localizedDescription)"))
        } else {
            flash?.fraction = 1
            flash?.phase = .done
            flash?.statusText = "Done."
            setStatus(deviceID, .connected)
            NotificationManager.shared.notify(
                .flashComplete, deviceName: device.displayName, detail: "",
                level: prefs.effectiveLevel)
            pushToast(Toast(kind: .flashSuccess, title: "Flash complete",
                            text: "\(device.displayName) — firmware written successfully"))
        }
        // Clear the inline flash UI after a beat.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.flash?.deviceID == deviceID { self.flash = nil }
        }
    }

    func cancelFlash() {
        flashTask?.cancel()
        flashTask = nil
        if let id = flash?.deviceID { setStatus(id, .connected) }
        flash = nil
    }

    // MARK: - Cloning & restore

    var canClone: (DetectedDevice) -> Bool { coordinator.canClone }

    func beginClone(deviceID: String) {
        guard flash == nil, let device = devices.first(where: { $0.id == deviceID }) else { return }
        guard coordinator.canClone(device) else { return }

        let ext = coordinator.cloneFileExtension(for: device)
        let dest = library.newFileURL(for: device, fileExtension: ext)
        flash = FlashState(deviceID: deviceID, kind: .clone, fraction: 0,
                           statusText: "Preparing…", phase: .running)
        setStatus(deviceID, .cloning)

        flashTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.coordinator.clone(from: device, to: dest) { fraction, text in
                    Task { @MainActor in
                        guard self.flash?.deviceID == deviceID else { return }
                        self.flash?.fraction = fraction
                        self.flash?.statusText = text
                    }
                }
                await self.finishClone(deviceID: deviceID, device: device, fileURL: dest, error: nil)
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: dest)
            } catch {
                try? FileManager.default.removeItem(at: dest)
                await self.finishClone(deviceID: deviceID, device: device, fileURL: dest, error: error)
            }
        }
    }

    private func finishClone(deviceID: String, device: DetectedDevice, fileURL: URL, error: Error?) {
        if let error {
            flash?.phase = .error
            flash?.statusText = error.localizedDescription
            setStatus(deviceID, .connected)
            pushToast(Toast(kind: .flashError, title: "Clone failed",
                            text: "\(device.displayName) — \(error.localizedDescription)"))
        } else {
            let backup = library.register(fileURL: fileURL, device: device)
            flash?.fraction = 1
            flash?.phase = .done
            flash?.statusText = "Saved \(backup.sizeDisplay)"
            setStatus(deviceID, .connected)
            pushToast(Toast(kind: .cloneSuccess, title: "Firmware cloned",
                            text: "\(device.displayName) — saved to Library (\(backup.sizeDisplay))"))
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.flash?.deviceID == deviceID { self.flash = nil }
        }
    }

    /// Restore a saved backup by flashing it back to a connected device.
    func restore(_ backup: FirmwareBackup, toDeviceID id: String) {
        beginFlash(deviceID: id, firmware: library.url(for: backup))
    }

    /// Connected devices a given backup can be restored to right now.
    func restoreTargets(for backup: FirmwareBackup) -> [DetectedDevice] {
        connectedDevices.filter { backup.isCompatible(with: $0) }
    }

    private func setStatus(_ id: String, _ status: DeviceStatus) {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[idx].status = status
    }

    // MARK: - Toasts

    private func pushToast(_ toast: Toast) {
        toasts.append(toast)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            toasts.removeAll { $0.id == toast.id }
        }
    }
}
