import SwiftUI

private struct SerialLine: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let level: Level
    enum Level { case plain, info, warn, error }
}

/// Live serial log viewer: baud presets, line endings, scrollback, pause/resume,
/// clear, export, optional timestamps, and a send bar.
struct SerialMonitorView: View {
    let deviceID: String
    @EnvironmentObject var app: AppState

    @StateObject private var model = SerialMonitorModel()
    @State private var baud = 115200
    @State private var lineEnding: LineEnding = .lf
    @State private var showTimestamps = false
    @State private var paused = false
    @State private var input = ""

    private let bauds = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]

    private var device: DetectedDevice? {
        app.devices.first { $0.id == deviceID }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Theme.borderLight)
            output
            Divider().overlay(Theme.borderLight)
            inputBar
        }
        .background(Theme.bg)
        .frame(minWidth: 560, minHeight: 420)
        .navigationTitle("Serial Monitor — \(device?.displayName ?? "")")
        .onAppear { connect() }
        .onDisappear { model.disconnect() }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Circle().fill(model.isConnected ? Theme.accent : Theme.muted)
                .frame(width: 5, height: 5)
            Text("Baud").font(Theme.body(10)).foregroundStyle(Theme.muted)
            Picker("", selection: $baud) {
                ForEach(bauds, id: \.self) { Text("\($0)").font(Theme.mono(10.5)).tag($0) }
            }
            .labelsHidden().frame(width: 90)
            .onChange(of: baud) { _ in reconnect() }

            Picker("", selection: $lineEnding) {
                ForEach(LineEnding.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden().frame(width: 110)

            Text(device?.calloutPath ?? "")
                .font(Theme.mono(10)).foregroundStyle(Theme.muted)

            Spacer()

            ctrl(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill",
                 active: paused) { paused.toggle() }
            ctrl("TS", systemImage: "clock", active: showTimestamps) { showTimestamps.toggle() }
            ctrl("Clear", systemImage: "trash") { model.clear() }
            ctrl("Export", systemImage: "square.and.arrow.up") { model.export() }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func ctrl(_ title: String, systemImage: String, active: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemImage).font(.system(size: 9))
                Text(title).font(Theme.body(10))
            }
            .foregroundStyle(active ? Theme.accent : Theme.muted)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(active ? Theme.accent : Theme.border))
        }
        .buttonStyle(.plain)
    }

    private var output: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.lines) { line in
                        HStack(alignment: .top, spacing: 6) {
                            if showTimestamps {
                                Text(Self.tsFormatter.string(from: line.timestamp))
                                    .font(Theme.mono(10)).foregroundStyle(Theme.muted)
                            }
                            Text(line.text)
                                .font(Theme.mono(11))
                                .foregroundStyle(color(line.level))
                                .textSelection(.enabled)
                        }
                        .id(line.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Color(oklch: (0.10, 0.005, 250)))
            .onChange(of: model.lines.count) { _ in
                if !paused, let last = model.lines.last {
                    withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            TextField("Send to device…", text: $input)
                .textFieldStyle(.plain)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border))
                .onSubmit(send)
            Button("Send", action: send)
                .buttonStyle(.plain)
                .font(Theme.body(10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Theme.accentBlue, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func color(_ level: SerialLine.Level) -> Color {
        switch level {
        case .plain: return Color(oklch: (0.78, 0.01, 140))
        case .info:  return Color(oklch: (0.70, 0.14, 200))
        case .warn:  return Theme.accentAmber
        case .error: return Theme.accentRed
        }
    }

    private func connect() {
        guard let path = device?.calloutPath else { return }
        model.connect(path: path, baud: baud) { paused }
    }
    private func reconnect() { model.disconnect(); connect() }
    private func send() {
        guard !input.isEmpty else { return }
        model.send(input, lineEnding: lineEnding)
        input = ""
    }

    static let tsFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()
}

/// Owns the SerialPort and the accumulated lines for the view.
@MainActor
private final class SerialMonitorModel: ObservableObject {
    @Published fileprivate var lines: [SerialLine] = []
    @Published var isConnected = false

    private let port = SerialPort()
    private var isPaused: () -> Bool = { false }

    func connect(path: String, baud: Int, paused: @escaping () -> Bool) {
        isPaused = paused
        port.onLine = { [weak self] text in
            guard let self, !self.isPaused() else { return }
            self.lines.append(SerialLine(timestamp: Date(), text: text, level: Self.classify(text)))
            if self.lines.count > 5000 { self.lines.removeFirst(self.lines.count - 5000) }
        }
        port.onClosed = { [weak self] in self?.isConnected = false }
        isConnected = port.open(path: path, baud: baud)
        if !isConnected {
            lines.append(SerialLine(timestamp: Date(),
                                    text: "Failed to open \(path) at \(baud) baud",
                                    level: .error))
        }
    }

    func disconnect() { port.close(); isConnected = false }
    func clear() { lines.removeAll() }
    func send(_ text: String, lineEnding: LineEnding) {
        port.write(text, lineEnding: lineEnding)
        lines.append(SerialLine(timestamp: Date(), text: "> \(text)", level: .info))
    }

    func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "serial-log.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = lines.map(\.text).joined(separator: "\n")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func classify(_ line: String) -> SerialLine.Level {
        if line.hasPrefix("E ") || line.contains("ERROR") || line.hasPrefix("E (") { return .error }
        if line.hasPrefix("W ") || line.contains("WARN")  || line.hasPrefix("W (") { return .warn }
        if line.hasPrefix("I ") || line.hasPrefix("I (") { return .info }
        return .plain
    }
}
