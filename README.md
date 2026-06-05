<p align="center">
  <img src="assets/icon.png" alt="Chirpset icon" width="128">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/wordmark-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/wordmark-light.png">
    <img src="assets/wordmark-dark.png" alt="Chirpset" width="440">
  </picture>
</p>

<p align="center">
  Serial devices, sorted. A macOS menu bar app for flashing and monitoring maker boards.
</p>

---

A macOS menu bar app for working with serial/USB maker boards — ESP32, Raspberry Pi Pico,
Arduino, and friends. It lives in the menu bar, keeps a live list of what's plugged in,
flashes firmware by drag-and-drop, and gives you a serial log viewer without juggling three
separate tools.

It also chirps when a board connects or disconnects, which is where the name comes from.

## What it does

- **Sees your boards.** Devices are enumerated over IOKit and identified by USB VID/PID, so
  you get "ESP32-S3" or "Raspberry Pi Pico", not just `/dev/cu.usbmodem1101`.
- **Notifies on hotplug.** Connect, disconnect, and bootloader-mode events fire a
  notification (and a chirp). Bootloader detection covers both USB re-enumeration and
  mass-storage volumes (`RPI-RP2`, `MAINTENANCE`, …).
- **Flashes firmware.** Drag a firmware file onto a device. Two backends under the hood:
  a native file copy for UF2/mass-storage boards (Pico, micro:bit) and a CLI subprocess
  (`esptool`, `avrdude`, …) for serial boards. Tools are resolved from the app bundle first,
  then a system install.
- **Clones and restores.** Read a board's firmware back out to a local library and re-flash
  it later. Backups live under `~/Library/Application Support/Chirpset/Firmware/`.
- **Serial monitor.** Baud presets, line endings, timestamps, pause/clear/export, and a
  send bar.

## Board support

Flashing works end-to-end today for ESP32, Raspberry Pi Pico, and Arduino (AVR). The other
families in the catalog (SAMD, micro:bit, STM32, Teensy) are detected and identified, with
flashing as a fast-follow.

## Building

Open `Chirpset/Chirpset.xcodeproj` in Xcode 16+ and run. Targets macOS 13+.

It's a non-sandboxed app (raw serial + IOKit + shelling out to flashing tools rule out the
App Store sandbox), distributed signed and notarized outside the App Store.

```
Scripts/fetch-tools.sh      # pull bundled flashing binaries into Chirpset/tools/
Scripts/GenerateAppIcon.swift  # regenerate the app icon from the bird mark
Scripts/package.sh          # archive, sign (Developer ID), notarize, staple, zip
```

## Status

Early but usable. Cloning round-trips and serial flashing need real hardware to fully
exercise; the mass-storage path and detection work as-is.
