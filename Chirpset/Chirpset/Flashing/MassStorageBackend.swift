import Foundation

/// Mass-storage flashing (Pico, micro:bit). In bootloader mode these mount as a
/// USB volume; flashing is just a file copy onto it, and the volume unmounting
/// signals success.
struct MassStorageBackend: FlashingBackend {

    func canHandle(_ device: DetectedDevice) -> Bool {
        device.board?.backend == .massStorage
    }

    func flash(firmware: URL,
               to device: DetectedDevice,
               progress: @escaping (Double, String) -> Void) async throws {
        guard let board = device.board else { throw FlashError.unsupportedDevice }
        guard let volumePath = device.volumePath, device.status == .bootloader else {
            throw FlashError.deviceNotInFlashableState
        }

        let ext = firmware.pathExtension.lowercased()
        guard board.firmwareExtensions.contains(ext) else {
            throw FlashError.badFirmware(
                "expected .\(board.firmwareExtensions.joined(separator: " / .")), got .\(ext)")
        }

        let volumeURL = URL(fileURLWithPath: volumePath)
        guard FileManager.default.fileExists(atPath: volumePath) else {
            throw FlashError.missingVolume(volumeURL.lastPathComponent)
        }

        progress(0.02, "Detected \(volumeURL.lastPathComponent) volume")

        let dest = volumeURL.appendingPathComponent(firmware.lastPathComponent)
        try await copyWithProgress(from: firmware, to: dest) { fraction in
            progress(0.05 + fraction * 0.9, "Copying \(firmware.lastPathComponent) → \(volumeURL.lastPathComponent)")
        }

        progress(0.97, "Finalizing write…")

        // Success is the volume unmounting as the board reboots. Wait briefly for it.
        let vanished = await waitForUnmount(path: volumePath, timeout: 8)
        if vanished {
            progress(1.0, "Volume ejected — board rebooting")
        } else {
            // Some boards keep the volume mounted; the copy still succeeded.
            progress(1.0, "Firmware written")
        }
    }

    // MARK: - Chunked copy

    private func copyWithProgress(from src: URL, to dest: URL,
                                  progress: @escaping (Double) -> Void) async throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: src.path)
        let total = (attrs[.size] as? Int64) ?? 0
        guard total > 0 else { throw FlashError.badFirmware("file is empty") }

        guard let input = InputStream(url: src) else {
            throw FlashError.badFirmware("cannot read \(src.lastPathComponent)")
        }
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        guard let output = OutputStream(url: dest, append: false) else {
            throw FlashError.badFirmware("cannot write to volume")
        }

        input.open(); output.open()
        defer { input.close(); output.close() }

        let chunkSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var written: Int64 = 0

        while input.hasBytesAvailable {
            try Task.checkCancellation()
            let read = input.read(&buffer, maxLength: chunkSize)
            if read < 0 { throw FlashError.badFirmware("read error") }
            if read == 0 { break }
            var offset = 0
            while offset < read {
                let n = output.write(&buffer[offset], maxLength: read - offset)
                if n <= 0 { throw FlashError.toolFailed(code: -1, message: "write error to volume") }
                offset += n
            }
            written += Int64(read)
            progress(min(Double(written) / Double(total), 1.0))
        }
    }

    private func waitForUnmount(path: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !FileManager.default.fileExists(atPath: path) { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }
}
