import SwiftUI
import UniformTypeIdentifiers

/// Drag-to-flash target. Accepts a dropped firmware file (or click to pick one)
/// and hands the URL back to the caller.
struct FlashZoneView: View {
    let device: DetectedDevice
    let onFirmware: (URL) -> Void

    @State private var isTargeted = false

    private var isMassStorage: Bool { device.board?.backend == .massStorage }

    private var prompt: String {
        if isMassStorage { return "Drop .uf2 file here" }
        let exts = device.board?.firmwareExtensions.map { ".\($0)" }.joined(separator: " / ") ?? "firmware"
        return "Drop \(exts) file here"
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(prompt)
                .font(Theme.body(11, weight: .semibold))
                .foregroundStyle(Theme.fgSecondary)
            Text("or click to select")
                .font(Theme.body(10))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            (isTargeted ? Theme.accentBlue.opacity(0.1) : Color.clear),
            in: RoundedRectangle(cornerRadius: Theme.radius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(isTargeted ? Theme.accentBlue : Theme.border)
        )
        .contentShape(Rectangle())
        .onTapGesture { pickFile() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async { onFirmware(url) }
        }
        return true
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let exts = device.board?.firmwareExtensions {
            panel.allowedContentTypes = exts.compactMap { UTType(filenameExtension: $0) }
        }
        if panel.runModal() == .OK, let url = panel.url {
            onFirmware(url)
        }
    }
}
