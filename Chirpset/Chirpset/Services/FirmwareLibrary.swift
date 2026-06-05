import Foundation
import Combine

/// Local store of cloned firmware images. Files and an `index.json` live under
/// `~/Library/Application Support/Chirpset/Firmware/`.
@MainActor
final class FirmwareLibrary: ObservableObject {
    @Published private(set) var backups: [FirmwareBackup] = []

    private let dir: URL
    private let indexURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Chirpset/Firmware", isDirectory: true)
        indexURL = dir.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    /// Directory where a new clone should be written. Returns a unique file URL.
    func newFileURL(for device: DetectedDevice, fileExtension ext: String) -> URL {
        let stamp = Self.fileStampFormatter.string(from: Date())
        let safeName = device.displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let name = "\(safeName)-\(stamp).\(ext)"
        return dir.appendingPathComponent(name)
    }

    func url(for backup: FirmwareBackup) -> URL {
        dir.appendingPathComponent(backup.fileName)
    }

    /// Register a freshly-written clone file as a backup.
    func register(fileURL: URL, device: DetectedDevice) -> FirmwareBackup {
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        let backup = FirmwareBackup(
            deviceName: device.displayName,
            boardID: device.board?.id,
            boardName: device.board?.displayName,
            vid: device.vid, pid: device.pid,
            serialNumber: device.serialNumber,
            fileName: fileURL.lastPathComponent,
            byteSize: size ?? 0)
        backups.insert(backup, at: 0)
        save()
        return backup
    }

    func delete(_ backup: FirmwareBackup) {
        try? FileManager.default.removeItem(at: url(for: backup))
        backups.removeAll { $0.id == backup.id }
        save()
    }

    func revealInFinder(_ backup: FirmwareBackup) {
        let fileURL = url(for: backup)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspaceReveal.reveal(fileURL)
        }
    }

    func compatibleBackups(for device: DetectedDevice) -> [FirmwareBackup] {
        backups.filter { $0.isCompatible(with: device) }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder.iso.decode([FirmwareBackup].self, from: data)
        else { return }
        // Drop entries whose file went missing.
        backups = decoded.filter { FileManager.default.fileExists(atPath: url(for: $0).path) }
    }

    private func save() {
        guard let data = try? JSONEncoder.iso.encode(backups) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    static let fileStampFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HHmmss"; return f
    }()
}

import AppKit
enum NSWorkspaceReveal {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = .prettyPrinted; return e }
}
extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
