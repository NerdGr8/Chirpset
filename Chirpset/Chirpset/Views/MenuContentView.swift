import SwiftUI

/// The menu bar panel: a scan indicator, the connected-device list, and a footer.
struct MenuContentView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            subtitle
            Divider().overlay(Theme.borderLight)
            deviceList
            Divider().overlay(Theme.borderLight)
            footer
        }
        .frame(width: 352)
        .background(Theme.bg)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 7) {
                BirdMark(size: 18, feet: false, traces: false, outerWaves: false)
                Text("Chirpset")
                    .font(Theme.display(13, weight: .bold))
                    .foregroundStyle(Theme.fg)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
                    .opacity(app.scanning ? 1 : 0.3)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: app.scanning)
                Text("Scanning")
                    .font(Theme.body(11, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
    }

    private var subtitle: some View {
        let count = app.connectedDevices.count
        return HStack {
            Text("\(count) device\(count == 1 ? "" : "s") connected")
                .font(Theme.body(11))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 4)
    }

    @ViewBuilder
    private var deviceList: some View {
        if app.connectedDevices.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(app.connectedDevices) { device in
                        DeviceCardView(device: device) { dev in
                            openSerial(dev)
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .frame(maxHeight: 460)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            DeviceIconView(kind: .generic, size: 40).opacity(0.3)
            Text("No devices detected")
                .font(Theme.body(13, weight: .semibold))
                .foregroundStyle(Theme.fgSecondary)
            Text("Plug in a serial device and it will appear here automatically.")
                .font(Theme.body(11))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40).padding(.horizontal, 20)
    }

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape").font(.system(size: 12))
                    Text("Settings").font(Theme.body(12))
                }
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button {
                openWindow(id: "library")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive.badge.timemachine").font(.system(size: 12))
                    Text("Library").font(Theme.body(12))
                }
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit").font(Theme.body(12)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Text("v0.1.0")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted.opacity(0.6))
                .padding(.leading, 4)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func openSerial(_ device: DetectedDevice) {
        openWindow(id: "serial", value: device.id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
