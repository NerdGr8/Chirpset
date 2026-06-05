# Chirpset — Product Requirements Document

**Working title:** Chirpset
**Type:** macOS menu bar utility for serial/USB maker hardware
**Status:** Draft v0.1
**Owner:** _TBD_
**Last updated:** June 2026

---

## 1. Summary

Chirpset is a lightweight macOS menu bar app for people who work with maker/embedded hardware (ESP32, Arduino, Raspberry Pi Pico, micro:bit, STM32, Teensy, and similar). It lives in the menu bar, continuously enumerates connected serial/USB devices, notifies the user the moment a device is plugged in or removed, lets them flash firmware by dragging a file onto a device, and provides a live serial log viewer.

The goal is to replace the current scattered workflow — juggling `esptool` on the command line, copying `.uf2` files in Finder, and opening a separate serial monitor — with one always-available menu bar surface.

---

## 2. Problem

Makers and embedded developers repeatedly do the same three things, each with a different tool:

- **Figure out what's connected.** `ls /dev/cu.*` tells you a path but not which board it is. Identifying a device by VID/PID is manual.
- **Flash firmware.** This means remembering the right CLI invocation per chip family, or dragging files onto a mounted volume for UF2 boards — two entirely different mental models.
- **Watch logs.** Requires launching a separate serial monitor and configuring the baud rate every time.

There is no single, low-friction, always-present surface that does all three. Chirpset is that surface.

---

## 3. Goals and non-goals

### Goals
- Be a near-zero-friction menu bar resident (no Dock icon, launches at login).
- Show an accurate, live list of connected serial/USB devices identified by board type, not just device path.
- Fire a system notification on device connect and disconnect.
- Make flashing firmware a drag-and-drop action for the boards where that is genuinely possible, and a clearly guided action where it is not.
- Provide a built-in serial log viewer with sensible baud-rate defaults.

### Non-goals (for v1)
- Not a full IDE or build system. Chirpset flashes prebuilt firmware; it does not compile.
- Not a replacement for vendor toolchains' advanced features (fuse bits, eFuse burning, secure-boot provisioning).
- No Windows or Linux version in v1 (macOS only).
- No cloud sync, accounts, or telemetry backend in v1.
- Not distributed via the Mac App Store in v1 (see §8).

---

## 4. Target users

- **The hobbyist maker.** Owns a handful of ESP32s and a Pico, follows tutorials, wants flashing to "just work" without the terminal.
- **The embedded developer.** Flashes the same boards dozens of times a day, wants speed, identity-at-a-glance, and a log viewer that doesn't get in the way.
- **The educator / workshop runner.** Manages a bench of micro:bits or Arduinos, needs to see what's plugged in and push firmware to devices quickly.

---

## 5. Key features

### 5.1 Menu bar presence
- Resident in the macOS menu bar via `MenuBarExtra` (macOS 13+).
- Runs as an agent (`LSUIElement`) — no Dock icon, no app-switcher entry.
- Launch-at-login option.
- The menu shows the current device list as the primary content.

### 5.2 Device enumeration
- Devices discovered and identified via **IOKit** (matching `kIOSerialBSDServiceValue`), not by globbing `/dev`.
- Each device displays: friendly board name (resolved from VID/PID), manufacturer, the `/dev/cu.*` path, and serial number where available.
- Devices already connected at launch appear immediately (initial-iterator drain).
- Mass-storage bootloader volumes (e.g. `RPI-RP2`, micro:bit `MAINTENANCE`) are recognized as flashable targets, not just regular drives.

### 5.3 Connect / disconnect / bootloader notifications
- A system notification (UserNotifications / `UNUserNotificationCenter`) fires on device connect and on disconnect.
- Notification names the board type where identifiable (e.g. "ESP32 connected").
- **Bootloader-mode notification:** when a device is detected in bootloader / DFU / mass-storage flashing mode, Chirpset fires a distinct notification — e.g. "Pico in bootloader mode — ready to flash" — and the menu entry visually flags the device as flash-ready. This is the cue that the user has successfully put the board into a flashable state.
- Detection of bootloader mode is driven by the board re-enumerating with a known bootloader VID/PID, or by a known bootloader volume mounting (see §7.1).
- Notifications are toggleable in preferences (all / connect-only / bootloader-only / off).

### 5.4 Firmware flashing (drag-to-flash)
- User drags a firmware file onto a device entry in the menu, or onto a device-detail window.
- Chirpset dispatches to the correct backend based on VID/PID (see §6).
- Live progress (percentage + status text) is shown during flashing.
- Clear success/failure feedback, with the underlying tool's error surfaced on failure.
- For boards that require manual bootloader entry, Chirpset shows a guided prompt instead of failing silently (see §7).

### 5.5 Serial log viewer
- Open a live serial monitor for any connected serial device.
- Configurable baud rate with common presets (115200 default) and line-ending options.
- Scrollback, pause/resume, clear, and copy/export to file.
- Optional timestamping of lines.

---

## 6. Flashing architecture (the core technical split)

Flashing is **not** a single operation. Chirpset abstracts it behind a `FlashingBackend` interface with two fundamentally different implementations, dispatched by USB VID/PID.

| Board family | Typical VID | Mechanism | Backend | Tool |
|---|---|---|---|---|
| ESP32 / ESP8266 (CP2102/CH340) | `0x10C4`, `0x1A86` | Serial, DTR/RTS auto-reset | Serial-tool | `esptool` |
| ESP32-S2/S3/C3 (native USB) | `0x303A` | Serial / USB-CDC | Serial-tool | `esptool` |
| Arduino Uno/Nano (AVR) | `0x2341`, `0x1A86`, `0x0403` | Serial, DTR reset | Serial-tool | `avrdude` |
| Arduino Zero/MKR (SAMD) | `0x2341`, `0x03EB` | 1200-baud touch → bootloader | Serial-tool | `bossac` |
| Raspberry Pi Pico (RP2040) | `0x2E8A` | UF2 mass-storage (BOOTSEL) | Mass-storage | drag `.uf2` / `picotool` |
| BBC micro:bit | `0x0D28` | MAINTENANCE mass-storage | Mass-storage | drag `.hex` |
| STM32 (Blue/Black Pill) | `0x0483` | USB DFU / serial bootloader | Serial-tool | `dfu-util` / `stm32flash` |
| Teensy | `0x16C0` | Custom HID | Serial-tool | `teensy_loader_cli` |

**Backend A — Mass-storage (Pico, micro:bit).** In bootloader mode these mount as a USB volume. Flashing *is* a file copy onto that volume; success is signaled by the volume disappearing. Drag-to-flash is fully native here.

**Backend B — Serial-tool (ESP, AVR, SAMD, STM32, Teensy).** Flashing is performed by a bundled, open-source CLI tool that Chirpset executes as a subprocess, streaming its stdout into the progress UI. The relevant tools (`esptool`, `avrdude`, `dfu-util`, etc.) are redistributable and shipped inside `Contents/Resources`.

```
protocol FlashingBackend {
    func canHandle(_ device: DetectedDevice) -> Bool
    func flash(firmware: URL, to device: DetectedDevice,
               progress: @escaping (Double, String) -> Void) async throws
}
```

---

## 7. Bootloader entry (key UX risk)

"Drag to flash" is only fully automatic for some boards. Chirpset must set honest expectations per family rather than implying universal magic.

- **Automatic (DTR/RTS auto-reset):** ESP32, Arduino AVR. These flash with no user intervention.
- **Software-triggered:** Arduino SAMD (Zero/MKR) require a 1200-baud open/close "touch" — Chirpset performs this automatically before flashing.
- **Manual button required:** Pico and micro:bit generally require holding BOOTSEL / reset while plugging in. Chirpset cannot force this in software for a fresh or crashed device, so it shows a "put your device in bootloader mode" prompt with board-specific instructions.
- **Manual jumper required:** STM32 DFU often needs the BOOT0 jumper set. Chirpset prompts for this.

**Requirement:** Chirpset must clearly distinguish, in UI copy, between boards that flash automatically and boards that need a manual step, and provide guided instructions for the latter.

### 7.1 Detecting bootloader mode

Chirpset must recognize when a board has entered a flashable state and notify the user (see §5.3). There are two detection paths:

- **Re-enumeration with a bootloader VID/PID.** Many boards present a *different* USB identity in bootloader/DFU mode than in run mode. The IOKit watcher matches incoming devices against a table of known bootloader identities — e.g. STM32 system DFU appears as `0x0483:0xDF11`, and native-USB ESP32-S2/S3/C3 expose a distinct download-mode PID. A match fires the "in bootloader mode" notification.
- **Bootloader volume mount.** Mass-storage boards mount a recognizable volume in bootloader mode — Pico as `RPI-RP2`, micro:bit as `MAINTENANCE`, SAMD boards as a bootloader drive. Chirpset watches volume-mount events (in addition to the IOKit serial watcher) and matches volume names against a known list.

When either path matches, the device is marked flash-ready in the menu and the bootloader notification is sent.

### 7.2 How to enter bootloader mode (per board)

Chirpset surfaces these board-specific instructions in the guided prompt when a manual step is required. Summary:

| Board | Enters boot mode automatically? | Manual entry steps |
|---|---|---|
| **ESP32 / ESP8266** (classic, CP2102/CH340) | Usually yes — esptool toggles DTR/RTS | If auto-reset fails: hold **BOOT** (GPIO0), tap **EN/RST**, then release **BOOT**. |
| **ESP32-S2 / S3 / C3** (native USB) | Sometimes | Hold **BOOT** (GPIO0), press and release **RESET**, then release **BOOT**. Re-enumerates in USB download mode. |
| **Arduino Uno / Nano** (AVR) | Yes — bootloader runs on reset, DTR auto-resets | No manual step normally. If unresponsive, press **RESET** just as flashing begins. |
| **Arduino Zero / MKR** (SAMD) | Software-triggered by Chirpset (1200-baud touch) | If the touch fails: **double-tap RESET** quickly to enter the SAM-BA bootloader (the bootloader drive should mount). |
| **Raspberry Pi Pico** (RP2040) | No | Hold the **BOOTSEL** button while plugging in USB → mounts as `RPI-RP2`. (A running Pico can be rebooted into BOOTSEL via `picotool`/software; a fresh or crashed one needs the button.) |
| **BBC micro:bit** | Mass-storage by default (`MICROBIT` drive) | For interface/MAINTENANCE mode: hold the **reset** button while plugging in USB → mounts as `MAINTENANCE`. |
| **STM32** (Blue/Black Pill) | No | Set the **BOOT0** jumper to **1** (BOOT1 to 0), press **RESET** → enters system bootloader (USB DFU or USART). Return BOOT0 to **0** and reset after flashing. |
| **Teensy** | No (HalfKay bootloader) | Press the onboard **program** pushbutton once to enter the HalfKay bootloader; Teensy Loader takes over. |

**Requirement:** the bootloader-mode notification and the guided entry instructions share one source of truth — a per-board definition table (run-mode VID/PID, bootloader VID/PID or volume name, auto/manual classification, and the instruction text above) — so detection and guidance never drift apart.

---

## 8. Technical and distribution constraints

- **Platform:** macOS 13+ (for `MenuBarExtra`). Confirm minimum during build-out.
- **Core APIs:** IOKit (enumeration + hotplug via `kIOMatchedNotification` / `kIOTerminatedNotification`), UserNotifications (toasts), termios or a Swift serial package (ORSSerialPort / SwiftSerial) for the log viewer, `Process` for serial-tool backends.
- **Sandboxing:** Raw serial/IOKit access and shelling out to bundled binaries are incompatible with the App Store sandbox (no clean public entitlement for arbitrary serial-port access). v1 is therefore a **non-sandboxed app**.
- **Distribution:** Developer ID–signed and **notarized**, distributed outside the Mac App Store (direct download). This must be planned from the start as it shapes entitlements and packaging.
- **Bundled tools licensing:** Verify and document the license of each bundled CLI tool and include attributions.

---

## 9. User flows

**Flash an ESP32**
1. User plugs in ESP32 → toast: "ESP32 connected."
2. Device appears in the menu with its name and port.
3. User drags `firmware.bin` onto the entry.
4. Chirpset selects the esptool backend, auto-resets the board, shows progress.
5. Success toast; device reboots into the new firmware.

**Flash a Pico**
1. User holds BOOTSEL and plugs in → Chirpset detects `RPI-RP2` volume → toast: "Pico in bootloader mode."
2. User drags `firmware.uf2` onto the entry.
3. Chirpset copies the file; volume unmounts → success.

**View logs**
1. User clicks a connected device → "Open Serial Monitor."
2. Log window opens at 115200 baud (adjustable), streaming live output with optional timestamps.

---

## 10. Success metrics

- **Time-to-flash:** median time from plugging in a known board to a successful flash (target: under 30 seconds for auto-reset boards).
- **Identification accuracy:** % of connected boards correctly named from VID/PID.
- **Flash success rate** per board family.
- **Retention:** weekly active makers who keep Chirpset in their menu bar.

---

## 11. Future / out of scope for v1

- Windows and Linux versions.
- Compiling firmware / build-system integration.
- Firmware library or version management (keeping a history of flashed builds per device).
- Multi-device batch flashing (bench/classroom mode).
- Advanced chip operations (fuses, eFuse, secure boot).
- Plugin system for community-contributed board definitions.

---

## 12. Open questions

- Minimum macOS version — is 13+ acceptable, or do we need to support older with `NSStatusItem`?
- Which board families are **must-have** for v1 vs. fast-follow? (Proposal: ESP32 + Pico + Arduino AVR for v1.)
- Do we bundle every CLI tool up front, or lazily download tool packs to keep the binary small?
- Free vs. paid, and if paid, one-time vs. subscription? (Affects distribution/licensing work.)
- Branding: confirm "Chirpset" availability (App name + trademark) before lock-in.
