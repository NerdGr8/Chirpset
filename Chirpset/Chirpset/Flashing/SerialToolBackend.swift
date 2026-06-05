import Foundation

/// Serial-tool flashing (ESP, AVR, SAMD, STM32, Teensy): runs a CLI tool as a
/// subprocess and streams its stdout into the progress UI.
///
/// If no tool binary is bundled in Contents/Resources/tools, ToolLocator falls
/// back to a system install; if neither exists, flashing throws .toolNotBundled.
struct SerialToolBackend: FlashingBackend {

    func canHandle(_ device: DetectedDevice) -> Bool {
        device.board?.backend == .serialTool && (device.board?.flashSupportedV1 ?? false)
    }

    func flash(firmware: URL,
               to device: DetectedDevice,
               progress: @escaping (Double, String) -> Void) async throws {
        guard let board = device.board else { throw FlashError.unsupportedDevice }
        guard let port = device.calloutPath else { throw FlashError.deviceNotInFlashableState }

        let ext = firmware.pathExtension.lowercased()
        guard board.firmwareExtensions.contains(ext) else {
            throw FlashError.badFirmware(
                "expected .\(board.firmwareExtensions.joined(separator: " / .")), got .\(ext)")
        }

        let tool = toolName(for: board)
        guard let source = ToolLocator.locate(tool) else {
            throw FlashError.toolNotBundled(tool)
        }

        let args = arguments(for: board, port: port, firmware: firmware)
        progress(0.02, "\(tool) (\(source.label.lowercased())) — \(port)")
        try await run(source.url, args: args, progress: progress)
    }

    // MARK: - Cloning (read flash back out)

    func canClone(_ device: DetectedDevice) -> Bool {
        guard let board = device.board, board.flashSupportedV1, device.calloutPath != nil else {
            return false
        }
        // Read-flash is supported by esptool and avrdude in v1.
        return board.id == "esp32-native" || board.id == "esp32-classic" || board.id == "arduino-avr"
    }

    func cloneFileExtension(for device: DetectedDevice) -> String {
        device.board?.id == "arduino-avr" ? "hex" : "bin"
    }

    func cloneFirmware(from device: DetectedDevice,
                       to destination: URL,
                       progress: @escaping (Double, String) -> Void) async throws {
        guard let board = device.board else { throw FlashError.unsupportedDevice }
        guard canClone(device) else { throw FlashError.cloneUnsupported }
        guard let port = device.calloutPath else { throw FlashError.deviceNotInFlashableState }

        let tool = toolName(for: board)
        guard let source = ToolLocator.locate(tool) else { throw FlashError.toolNotBundled(tool) }

        let args = readArguments(for: board, port: port, destination: destination)
        progress(0.02, "\(tool) (\(source.label.lowercased())) — reading \(port)")
        try await run(source.url, args: args, progress: progress)

        guard FileManager.default.fileExists(atPath: destination.path),
              let size = try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64,
              (size ?? 0) > 0 else {
            throw FlashError.toolFailed(code: -1, message: "no firmware was read")
        }
    }

    private func readArguments(for board: BoardDefinition, port: String, destination: URL) -> [String] {
        switch board.id {
        case "esp32-native", "esp32-classic":
            // Read the entire flash. esptool's ALL keyword sizes it automatically.
            return ["--port", port, "--baud", "460800", "read_flash", "0", "ALL", destination.path]
        case "arduino-avr":
            return ["-patmega328p", "-carduino", "-P", port, "-b", "115200",
                    "-U", "flash:r:\(destination.path):i"]
        default:
            return ["--port", port, "read_flash", "0", "ALL", destination.path]
        }
    }

    // MARK: - Tool selection

    private func toolName(for board: BoardDefinition) -> String {
        switch board.id {
        case "esp32-native", "esp32-classic": return "esptool"
        case "arduino-avr":                    return "avrdude"
        case "arduino-samd":                   return "bossac"
        case "stm32":                          return "dfu-util"
        case "teensy":                         return "teensy_loader_cli"
        default:                               return "esptool"
        }
    }

    private func arguments(for board: BoardDefinition, port: String, firmware: URL) -> [String] {
        switch board.id {
        case "esp32-native", "esp32-classic":
            return ["--port", port, "--baud", "460800",
                    "write_flash", "0x10000", firmware.path]
        case "arduino-avr":
            return ["-v", "-patmega328p", "-carduino", "-P", port, "-b", "115200",
                    "-D", "-Uflash:w:\(firmware.path):i"]
        default:
            return ["--port", port, firmware.path]
        }
    }

    // MARK: - Subprocess

    private func run(_ tool: URL, args: [String],
                     progress: @escaping (Double, String) -> Void) async throws {
        let process = Process()
        process.executableURL = tool
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let handle = pipe.fileHandleForReading

        try process.run()

        var lastFraction = 0.05
        for try await line in handle.bytes.lines {
            try Task.checkCancellation()
            if let pct = parsePercent(line) {
                lastFraction = max(lastFraction, pct)
            } else {
                lastFraction = min(lastFraction + 0.01, 0.95)
            }
            progress(lastFraction, line.trimmingCharacters(in: .whitespaces))
        }

        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw FlashError.toolFailed(code: process.terminationStatus,
                                        message: "see log above")
        }
        progress(1.0, "Done.")
    }

    /// Extract a percentage from common tool output (e.g. "Writing at … (50%)").
    private func parsePercent(_ line: String) -> Double? {
        guard let range = line.range(of: #"(\d{1,3})\s*%"#, options: .regularExpression) else {
            return nil
        }
        let digits = line[range].filter(\.isNumber)
        guard let value = Double(digits) else { return nil }
        return min(value / 100.0, 1.0)
    }
}

private extension FileHandle {
    /// Async byte stream over the handle (AsyncSequence) — `.lines` splits on newlines.
    var bytes: AsyncStream<UInt8> {
        AsyncStream { continuation in
            self.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.finish()
                    return
                }
                for byte in data { continuation.yield(byte) }
            }
        }
    }
}

private extension AsyncStream where Element == UInt8 {
    /// Group the byte stream into lines.
    var lines: AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var buffer: [UInt8] = []
                for await byte in self {
                    if byte == UInt8(ascii: "\n") {
                        continuation.yield(String(decoding: buffer, as: UTF8.self))
                        buffer.removeAll(keepingCapacity: true)
                    } else if byte != UInt8(ascii: "\r") {
                        buffer.append(byte)
                    }
                }
                if !buffer.isEmpty {
                    continuation.yield(String(decoding: buffer, as: UTF8.self))
                }
                continuation.finish()
            }
        }
    }
}
