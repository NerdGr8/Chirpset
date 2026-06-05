import SwiftUI

/// Browse cloned firmware backups, restore them to a connected device, reveal
/// the file, or delete it.
struct FirmwareLibraryView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var library: FirmwareLibrary

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.borderLight)
            if library.backups.isEmpty { empty } else { list }
        }
        .frame(width: 560, height: 420)
        .background(Theme.bg)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive.badge.timemachine")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Firmware Library").font(Theme.body(13, weight: .bold)).foregroundStyle(Theme.fg)
                Text("\(library.backups.count) backup\(library.backups.count == 1 ? "" : "s")")
                    .font(Theme.body(10)).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.system(size: 32)).foregroundStyle(Theme.muted.opacity(0.5))
            Text("No backups yet").font(Theme.body(13, weight: .semibold)).foregroundStyle(Theme.fgSecondary)
            Text("Expand a connected ESP32 or Arduino in the menu and choose “Clone firmware” to save a restorable copy here.")
                .font(Theme.body(11)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(library.backups) { backup in
                    row(backup)
                }
            }
            .padding(12)
        }
    }

    private func row(_ backup: FirmwareBackup) -> some View {
        let targets = app.restoreTargets(for: backup)
        return HStack(spacing: 12) {
            DeviceIconView(kind: boardIcon(backup), size: 26)
                .frame(width: 34, height: 34)
                .background(boardIcon(backup).accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(backup.deviceName).font(Theme.body(12, weight: .semibold)).foregroundStyle(Theme.fg)
                    .lineLimit(1).truncationMode(.tail)
                Text("\(backup.boardName ?? "Unknown") · \(backup.sizeDisplay) · \(backup.createdDisplay)")
                    .font(Theme.mono(10)).foregroundStyle(Theme.muted)
                    .lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 6)

            if targets.isEmpty {
                Text("No target connected")
                    .font(Theme.body(10)).foregroundStyle(Theme.muted)
            } else if targets.count == 1 {
                smallButton("Restore", systemImage: "arrow.uturn.backward", tint: Theme.accentBlue) {
                    app.restore(backup, toDeviceID: targets[0].id)
                }
            } else {
                Menu("Restore…") {
                    ForEach(targets) { target in
                        Button(target.displayName) { app.restore(backup, toDeviceID: target.id) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            smallButton("Reveal", systemImage: "magnifyingglass", tint: Theme.fgSecondary) {
                library.revealInFinder(backup)
            }
            smallButton("Delete", systemImage: "trash", tint: Theme.accentRed) {
                library.delete(backup)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    private func boardIcon(_ backup: FirmwareBackup) -> BoardIconKind {
        BoardCatalog.all.first { $0.id == backup.boardID }?.icon ?? .generic
    }

    private func smallButton(_ title: String, systemImage: String, tint: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemImage).font(.system(size: 10))
                Text(title).font(Theme.body(10, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(tint.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}
