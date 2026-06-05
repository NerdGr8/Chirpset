import SwiftUI

/// How a board is flashed once it's in a flashable state.
enum FlashBackendKind: String {
    case serialTool      // esptool / avrdude / bossac / dfu-util / stm32flash / teensy_loader_cli
    case massStorage     // drag a .uf2 / .hex onto a mounted volume
}

/// How a board enters its flashable (bootloader) state.
enum BootloaderEntry {
    case automatic                 // DTR/RTS auto-reset — no user action (ESP32 classic, AVR)
    case softwareTriggered         // Chirpset performs a 1200-baud touch (SAMD)
    case manualButton              // user holds BOOTSEL/reset while plugging in (Pico, micro:bit)
    case manualJumper              // user sets a jumper (STM32 BOOT0)
    case manualProgramButton       // user presses on-board program button (Teensy)

    var isAutomatic: Bool {
        switch self {
        case .automatic, .softwareTriggered: return true
        case .manualButton, .manualJumper, .manualProgramButton: return false
        }
    }
}

/// Visual family used to pick an icon + accent in the UI.
enum BoardIconKind {
    case esp, pico, avr, samd, stm, microbit, teensy, generic

    var accent: Color {
        switch self {
        case .esp:      return Theme.accent
        case .pico:     return Theme.accentAmber
        case .avr:      return Theme.accentBlue
        case .samd:     return Theme.accentBlue
        case .stm:      return Color(oklch: (0.72, 0.12, 300))
        case .microbit: return Theme.accent
        case .teensy:   return Theme.accentAmber
        case .generic:  return Theme.muted
        }
    }
}

/// One source of truth for a board: run-mode and bootloader USB identities, the
/// flashing mechanism, how it enters bootloader mode, and the guided instruction
/// text. Keeping it together means detection and guidance can't drift apart.
struct BoardDefinition: Identifiable {
    let id: String
    let displayName: String
    let manufacturer: String
    let backend: FlashBackendKind
    let icon: BoardIconKind
    let entry: BootloaderEntry

    /// USB identities in normal run mode. `pids` empty means "match any PID for this VID".
    let runVIDs: [UInt16]
    let runPIDs: [UInt16]

    /// Distinct USB identity presented in bootloader/DFU mode, if the board re-enumerates.
    let bootloaderVID: UInt16?
    let bootloaderPID: UInt16?

    /// Volume name(s) that mount when this board is in mass-storage bootloader mode.
    let bootloaderVolumes: [String]

    /// File extensions Chirpset will accept for flashing this board.
    let firmwareExtensions: [String]

    /// Whether v1 can flash this board end-to-end, vs. detect/identify only.
    let flashSupportedV1: Bool

    /// Board-specific manual bootloader-entry steps (empty when fully automatic).
    let bootloaderInstructions: [String]

    /// Short tool name surfaced in the UI ("esptool", "Mass-storage (UF2)", …).
    let backendLabel: String
}

enum BoardCatalog {

    /// The catalog. ESP32 / Pico / Arduino AVR are flash-supported in v1;
    /// the rest are detected and identified, with flashing as fast-follow.
    static let all: [BoardDefinition] = [

        // ── ESP32-S2/S3/C3 (native USB) ───────────────────────────────
        BoardDefinition(
            id: "esp32-native",
            displayName: "ESP32-S/C (native USB)",
            manufacturer: "Espressif Systems",
            backend: .serialTool, icon: .esp, entry: .manualButton,
            runVIDs: [0x303A], runPIDs: [],
            bootloaderVID: 0x303A, bootloaderPID: 0x0002, // USB download mode
            bootloaderVolumes: [],
            firmwareExtensions: ["bin"],
            flashSupportedV1: true,
            bootloaderInstructions: [
                "Hold the BOOT (GPIO0) button.",
                "Press and release RESET.",
                "Release BOOT — the board re-enumerates in USB download mode."
            ],
            backendLabel: "Serial (esptool)"
        ),

        // ── ESP32 / ESP8266 classic (CP2102 / CH340 bridge) ───────────
        BoardDefinition(
            id: "esp32-classic",
            displayName: "ESP32 / ESP8266",
            manufacturer: "Espressif (USB-serial bridge)",
            backend: .serialTool, icon: .esp, entry: .automatic,
            runVIDs: [0x10C4, 0x1A86], runPIDs: [],
            bootloaderVID: nil, bootloaderPID: nil,
            bootloaderVolumes: [],
            firmwareExtensions: ["bin"],
            flashSupportedV1: true,
            bootloaderInstructions: [
                "esptool toggles DTR/RTS automatically — usually no action needed.",
                "If auto-reset fails: hold BOOT (GPIO0), tap EN/RST, then release BOOT."
            ],
            backendLabel: "Serial (esptool)"
        ),

        // ── Arduino Uno / Nano (AVR) ──────────────────────────────────
        BoardDefinition(
            id: "arduino-avr",
            displayName: "Arduino Uno / Nano (AVR)",
            manufacturer: "Arduino",
            backend: .serialTool, icon: .avr, entry: .automatic,
            runVIDs: [0x2341, 0x2A03], runPIDs: [],
            bootloaderVID: nil, bootloaderPID: nil,
            bootloaderVolumes: [],
            firmwareExtensions: ["hex"],
            flashSupportedV1: true,
            bootloaderInstructions: [
                "The bootloader runs on reset and DTR auto-resets the board — no manual step.",
                "If unresponsive, press RESET just as flashing begins."
            ],
            backendLabel: "Serial (avrdude)"
        ),

        // ── Raspberry Pi Pico (RP2040) ────────────────────────────────
        BoardDefinition(
            id: "rp2040",
            displayName: "Raspberry Pi Pico (RP2040)",
            manufacturer: "Raspberry Pi",
            backend: .massStorage, icon: .pico, entry: .manualButton,
            runVIDs: [0x2E8A], runPIDs: [],
            bootloaderVID: 0x2E8A, bootloaderPID: 0x0003, // BOOTSEL mass storage
            bootloaderVolumes: ["RPI-RP2", "RP2350"],
            firmwareExtensions: ["uf2"],
            flashSupportedV1: true,
            bootloaderInstructions: [
                "Hold the BOOTSEL button while plugging in USB.",
                "The board mounts as the RPI-RP2 volume — then it's ready to flash."
            ],
            backendLabel: "Mass-storage (UF2)"
        ),

        // ── Arduino Zero / MKR (SAMD) ─────────────────────────────────
        BoardDefinition(
            id: "arduino-samd",
            displayName: "Arduino Zero / MKR (SAMD)",
            manufacturer: "Arduino",
            backend: .serialTool, icon: .samd, entry: .softwareTriggered,
            runVIDs: [0x2341, 0x03EB], runPIDs: [],
            bootloaderVID: nil, bootloaderPID: nil,
            bootloaderVolumes: ["BOOT", "ARDUINO"],
            firmwareExtensions: ["bin"],
            flashSupportedV1: false,
            bootloaderInstructions: [
                "Chirpset performs a 1200-baud touch to enter the bootloader automatically.",
                "If that fails: double-tap RESET quickly to enter the SAM-BA bootloader."
            ],
            backendLabel: "Serial (bossac)"
        ),

        // ── BBC micro:bit ─────────────────────────────────────────────
        BoardDefinition(
            id: "microbit",
            displayName: "BBC micro:bit",
            manufacturer: "BBC / Micro:bit Foundation",
            backend: .massStorage, icon: .microbit, entry: .manualButton,
            runVIDs: [0x0D28], runPIDs: [],
            bootloaderVID: nil, bootloaderPID: nil,
            bootloaderVolumes: ["MICROBIT", "MAINTENANCE"],
            firmwareExtensions: ["hex"],
            flashSupportedV1: false,
            bootloaderInstructions: [
                "The micro:bit mounts as the MICROBIT drive by default.",
                "For interface/MAINTENANCE mode: hold reset while plugging in USB."
            ],
            backendLabel: "Mass-storage (HEX)"
        ),

        // ── STM32 (Blue/Black Pill) ───────────────────────────────────
        BoardDefinition(
            id: "stm32",
            displayName: "STM32 (Blue/Black Pill)",
            manufacturer: "STMicroelectronics",
            backend: .serialTool, icon: .stm, entry: .manualJumper,
            runVIDs: [0x0483], runPIDs: [],
            bootloaderVID: 0x0483, bootloaderPID: 0xDF11, // system DFU
            bootloaderVolumes: [],
            firmwareExtensions: ["bin", "hex", "dfu"],
            flashSupportedV1: false,
            bootloaderInstructions: [
                "Set the BOOT0 jumper to 1 (ensure BOOT1 is 0).",
                "Press RESET — the board enters the system bootloader (USB DFU).",
                "Return BOOT0 to 0 and reset after flashing."
            ],
            backendLabel: "Serial (dfu-util)"
        ),

        // ── Teensy ────────────────────────────────────────────────────
        BoardDefinition(
            id: "teensy",
            displayName: "Teensy",
            manufacturer: "PJRC",
            backend: .serialTool, icon: .teensy, entry: .manualProgramButton,
            runVIDs: [0x16C0], runPIDs: [],
            bootloaderVID: 0x16C0, bootloaderPID: 0x0478, // HalfKay
            bootloaderVolumes: [],
            firmwareExtensions: ["hex"],
            flashSupportedV1: false,
            bootloaderInstructions: [
                "Press the on-board program pushbutton once to enter the HalfKay bootloader.",
                "Teensy Loader then takes over."
            ],
            backendLabel: "Serial (teensy_loader_cli)"
        ),
    ]

    /// Resolve a USB VID/PID to a board definition and whether it matched a
    /// *bootloader* identity (vs. a run-mode identity).
    static func match(vid: UInt16, pid: UInt16) -> (board: BoardDefinition, isBootloader: Bool)? {
        // Prefer a bootloader-identity match (more specific) before run-mode.
        for b in all where b.bootloaderVID == vid && b.bootloaderPID == pid {
            return (b, true)
        }
        for b in all where b.runVIDs.contains(vid) {
            if b.runPIDs.isEmpty || b.runPIDs.contains(pid) { return (b, false) }
        }
        return nil
    }

    /// Resolve a mounted volume name to a board in mass-storage bootloader mode.
    static func match(volumeName: String) -> BoardDefinition? {
        all.first { $0.bootloaderVolumes.contains(volumeName) }
    }
}
