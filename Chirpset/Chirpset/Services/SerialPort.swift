import Foundation

/// A line-ending option for the serial input bar.
enum LineEnding: String, CaseIterable, Identifiable {
    case none = "None"
    case lf = "LF (\\n)"
    case cr = "CR (\\r)"
    case crlf = "CRLF (\\r\\n)"

    var id: String { rawValue }
    var bytes: String {
        switch self {
        case .none: return ""
        case .lf:   return "\n"
        case .cr:   return "\r"
        case .crlf: return "\r\n"
        }
    }
}

/// POSIX/termios serial reader for the log viewer. Opens a /dev/cu.* device at a
/// baud rate, streams incoming lines, and writes back. Reads run on a background
/// queue; callbacks land on main.
final class SerialPort {

    /// Emitted on the main thread for each complete line received.
    var onLine: ((String) -> Void)?
    /// Emitted on the main thread if the port closes unexpectedly.
    var onClosed: (() -> Void)?

    private(set) var path: String = ""
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "co.machinekind.chirpset.serial")
    private var reading = false
    private var lineBuffer = Data()

    var isOpen: Bool { fd >= 0 }

    func open(path: String, baud: Int) -> Bool {
        close()
        self.path = path

        let handle = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard handle >= 0 else { return false }

        // Restore blocking mode for reads.
        _ = fcntl(handle, F_SETFL, 0)

        var settings = termios()
        guard tcgetattr(handle, &settings) == 0 else {
            Darwin.close(handle); return false
        }
        cfmakeraw(&settings)
        cfsetispeed(&settings, speed_t(baud))
        cfsetospeed(&settings, speed_t(baud))
        settings.c_cflag |= tcflag_t(CREAD | CLOCAL)
        // VMIN=0, VTIME=1 → return promptly so we can poll the cancel flag.
        withUnsafeMutableBytes(of: &settings.c_cc) { raw in
            raw[Int(VMIN)] = 0
            raw[Int(VTIME)] = 1
        }
        guard tcsetattr(handle, TCSANOW, &settings) == 0 else {
            Darwin.close(handle); return false
        }

        fd = handle
        reading = true
        queue.async { [weak self] in self?.readLoop() }
        return true
    }

    func write(_ text: String, lineEnding: LineEnding) {
        guard isOpen else { return }
        let payload = text + lineEnding.bytes
        let data = Data(payload.utf8)
        queue.async { [fd] in
            data.withUnsafeBytes { raw in
                _ = Darwin.write(fd, raw.baseAddress, raw.count)
            }
        }
    }

    func close() {
        reading = false
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        lineBuffer.removeAll()
    }

    deinit { close() }

    private func readLoop() {
        var chunk = [UInt8](repeating: 0, count: 4096)
        while reading && fd >= 0 {
            let n = Darwin.read(fd, &chunk, chunk.count)
            if n > 0 {
                process(bytes: chunk, count: n)
            } else if n == 0 {
                continue
            } else {
                // EAGAIN under non-blocking edge cases; brief pause then retry.
                if errno == EAGAIN { usleep(2000); continue }
                break
            }
        }
        if reading {
            // Unexpected close.
            DispatchQueue.main.async { [weak self] in self?.onClosed?() }
        }
    }

    private func process(bytes: [UInt8], count: Int) {
        lineBuffer.append(contentsOf: bytes[0..<count])
        while let idx = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = lineBuffer.subdata(in: lineBuffer.startIndex..<idx)
            lineBuffer.removeSubrange(lineBuffer.startIndex...idx)
            var line = String(decoding: lineData, as: UTF8.self)
            if line.hasSuffix("\r") { line.removeLast() }
            DispatchQueue.main.async { [weak self] in self?.onLine?(line) }
        }
    }
}
