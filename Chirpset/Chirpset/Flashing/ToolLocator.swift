import Foundation

/// Resolves a flashing CLI tool: a bundled copy first, then a system install.
/// That way ESP32/AVR flashing works for anyone who already has esptool/avrdude
/// (Homebrew, pip, Arduino IDE), with the bundled copy as the shipping default.
enum ToolLocator {

    enum Source: Equatable {
        case bundled(URL)
        case system(URL)

        var url: URL {
            switch self {
            case .bundled(let u), .system(let u): return u
            }
        }
        var label: String {
            switch self {
            case .bundled: return "Bundled"
            case .system:  return "System"
            }
        }
    }

    /// Common install locations to probe in addition to `$PATH`.
    private static let extraDirs = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "\(NSHomeDirectory())/.local/bin",
        "\(NSHomeDirectory())/Library/Python/3.9/bin",
        "\(NSHomeDirectory())/Library/Python/3.11/bin",
        "\(NSHomeDirectory())/Library/Python/3.12/bin",
    ]

    static func locate(_ name: String) -> Source? {
        if let bundled = bundledURL(name) { return .bundled(bundled) }
        if let system = systemURL(name) { return .system(system) }
        return nil
    }

    /// Bundled tools live in `Chirpset.app/Contents/Resources/tools/<name>`.
    static func bundledURL(_ name: String) -> URL? {
        guard let url = Bundle.main.resourceURL?
            .appendingPathComponent("tools", isDirectory: true)
            .appendingPathComponent(name) else { return nil }
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    static func systemURL(_ name: String) -> URL? {
        let fm = FileManager.default
        var dirs = extraDirs
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            dirs += path.split(separator: ":").map(String.init)
        }
        for dir in dirs {
            let candidate = (dir as NSString).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate) { return URL(fileURLWithPath: candidate) }
        }
        return nil
    }
}
