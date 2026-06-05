import SwiftUI

/// A single device entry in the menu panel: summary row plus an expandable
/// detail section with flash zone, bootloader guidance, and actions.
struct DeviceCardView: View {
    let device: DetectedDevice
    @EnvironmentObject var app: AppState
    let onOpenSerial: (DetectedDevice) -> Void

    private var isExpanded: Bool { app.selectedDeviceID == device.id }
    private var isOperating: Bool { app.flash?.deviceID == device.id }
    private var operationKind: FlashState.Kind? {
        app.flash?.deviceID == device.id ? app.flash?.kind : nil
    }
    private var effectiveStatus: DeviceStatus {
        switch operationKind {
        case .clone: return .cloning
        case .flash: return .flashing
        case nil:    return device.status
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            if isExpanded { detail.padding(.horizontal, 10).padding(.bottom, 10) }
        }
        .background(
            (isExpanded ? Color.white.opacity(0.05) : Color.clear),
            in: RoundedRectangle(cornerRadius: Theme.radius)
        )
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }

    // MARK: Summary

    private var summary: some View {
        HStack(spacing: 10) {
            DeviceIconView(kind: device.board?.icon ?? .generic)
                .frame(width: 32, height: 32)
                .background(device.iconAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(device.displayName)
                    .font(Theme.body(12, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1).truncationMode(.tail)
                Text(device.pathDisplay)
                    .font(Theme.mono(10))
                    .foregroundStyle(device.isVolumeDevice ? Theme.accentAmber : Theme.muted)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 6)
            StatusBadge(status: effectiveStatus)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { app.select(device.id) }
    }

    // MARK: Detail

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(Theme.borderLight)
            detailGrid.padding(.vertical, 8)

            if device.detectedInBootloader, let note = device.board?.bootloaderInstructions.first {
                Text(note)
                    .font(Theme.body(10, weight: .medium))
                    .foregroundStyle(Theme.accentAmber)
                    .padding(.bottom, 4)
            }

            if device.needsManualBootloaderEntry, let board = device.board {
                bootloaderInstructions(board)
            }

            Divider().overlay(Theme.borderLight).padding(.vertical, 4)

            if isOperating { flashProgress }
            else if device.isFlashable {
                FlashZoneView(device: device) { url in
                    app.beginFlash(deviceID: device.id, firmware: url)
                }
            } else if device.board?.flashSupportedV1 == false {
                Text("Detection only — flashing for this board lands in a later release.")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.muted)
            }

            if !isOperating { backupControls.padding(.top, 8) }
            actions.padding(.top, 8)
        }
    }

    private var detailGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 3) {
            row("Manufacturer", device.manufacturerName)
            row("VID:PID", device.vidPidString)
            if let serial = device.serialNumber { row("Serial", serial) }
            row("Backend", device.backendLabel)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(Theme.body(11, weight: .medium))
                .foregroundStyle(Theme.muted)
                .gridColumnAlignment(.leading)
            Text(value)
                .font(Theme.mono(10.5))
                .foregroundStyle(Theme.fgSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1).truncationMode(.middle)
        }
    }

    private func bootloaderInstructions(_ board: BoardDefinition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manual bootloader entry required")
                .font(Theme.body(10.5, weight: .semibold))
                .foregroundStyle(Theme.accentAmber)
            ForEach(Array(board.bootloaderInstructions.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(i + 1).").font(Theme.mono(10)).foregroundStyle(Theme.muted)
                    Text(step).font(Theme.body(10.5)).foregroundStyle(Theme.fgSecondary)
                }
            }
            if device.status != .bootloader {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Waiting for bootloader mode…")
                        .font(Theme.body(10, weight: .medium))
                        .foregroundStyle(Theme.accentAmber)
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Theme.accentAmber.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.accentAmber.opacity(0.15))
        )
    }

    private var flashProgress: some View {
        let fs = app.flash
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border).frame(height: 4)
                    Capsule()
                        .fill(barColor(fs?.phase))
                        .frame(width: geo.size.width * (fs?.fraction ?? 0), height: 4)
                        .animation(.easeOut(duration: 0.3), value: fs?.fraction)
                }
            }
            .frame(height: 4)

            HStack {
                Text(percentLabel(fs))
                    .font(Theme.mono(10)).foregroundStyle(Theme.fgSecondary)
                Spacer()
                Text(fs?.statusText ?? "")
                    .font(Theme.mono(10)).foregroundStyle(Theme.muted)
                    .lineLimit(1).truncationMode(.head)
                    .frame(maxWidth: 180, alignment: .trailing)
            }

            if fs?.phase == .running {
                Button("Cancel") { app.cancelFlash() }
                    .buttonStyle(.plain)
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border))
            }
            if fs?.phase == .done {
                Text(fs?.kind == .clone
                     ? "Firmware cloned — saved to Library"
                     : "Firmware flashed successfully — device rebooting")
                    .font(Theme.body(10)).foregroundStyle(Theme.accent)
            }
        }
        .padding(.top, 4)
    }

    private func barColor(_ phase: FlashState.Phase?) -> Color {
        switch phase {
        case .done:  return Theme.accent
        case .error: return Theme.accentRed
        default:     return Theme.accentBlue
        }
    }

    private func percentLabel(_ fs: FlashState?) -> String {
        switch fs?.phase {
        case .done:  return fs?.kind == .clone ? "Saved" : "Complete"
        case .error: return "Failed"
        default:     return "\(Int((fs?.fraction ?? 0) * 100))%"
        }
    }

    // MARK: Backup / restore

    @ViewBuilder
    private var backupControls: some View {
        let canClone = app.canClone(device)
        let restorable = app.library.compatibleBackups(for: device)
        if canClone || !restorable.isEmpty {
            HStack(spacing: 6) {
                if canClone {
                    actionButton("Clone firmware", systemImage: "doc.on.doc") {
                        app.beginClone(deviceID: device.id)
                    }
                }
                if !restorable.isEmpty {
                    Menu {
                        ForEach(restorable) { backup in
                            Button {
                                app.restore(backup, toDeviceID: device.id)
                            } label: {
                                Text("\(backup.createdDisplay) · \(backup.sizeDisplay)")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 11))
                            Text("Restore").font(Theme.body(11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(Theme.fgSecondary)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.border))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 6) {
            if device.calloutPath != nil {
                actionButton("Serial Monitor", systemImage: "terminal") {
                    onOpenSerial(device)
                }
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 11))
                Text(title).font(Theme.body(11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(Theme.fgSecondary)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.border))
        }
        .buttonStyle(.plain)
    }
}
