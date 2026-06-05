import Foundation

/// Metadata for a cloned firmware image stored in the local library. The actual
/// binary lives alongside as `fileName` inside the library directory.
struct FirmwareBackup: Identifiable, Codable, Equatable {
    let id: UUID
    let deviceName: String
    let boardID: String?        // BoardDefinition.id at clone time
    let boardName: String?
    let vid: UInt16?
    let pid: UInt16?
    let serialNumber: String?
    let fileName: String        // relative to the library directory
    let byteSize: Int64
    let createdAt: Date

    init(id: UUID = UUID(), deviceName: String, boardID: String?, boardName: String?,
         vid: UInt16?, pid: UInt16?, serialNumber: String?,
         fileName: String, byteSize: Int64, createdAt: Date = Date()) {
        self.id = id
        self.deviceName = deviceName
        self.boardID = boardID
        self.boardName = boardName
        self.vid = vid
        self.pid = pid
        self.serialNumber = serialNumber
        self.fileName = fileName
        self.byteSize = byteSize
        self.createdAt = createdAt
    }

    var sizeDisplay: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    var createdDisplay: String {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: createdAt)
    }

    /// Whether this backup can be restored to the given connected device:
    /// same board family, or matching USB identity.
    func isCompatible(with device: DetectedDevice) -> Bool {
        if let boardID, boardID == device.board?.id { return true }
        if let vid, let pid, vid == device.vid, pid == device.pid { return true }
        return false
    }
}
