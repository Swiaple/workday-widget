# Workday Widget

[中文](README.md) · [English](README_EN.md)

A compact desktop work-hours widget. Enter when you started work and it calculates the planned clock-out time from your saved schedule, then continuously shows today's progress, overtime, and work history.

- **Current stable release:** 3.5 (Build 12, macOS only)
- **Cross-platform release:** 4.0.0-beta.2 (macOS / Windows 11, in development)
- **Minimum systems:** macOS 13.0 / Windows 11
- **License:** MIT

The stable app is written in Objective-C and AppKit. The `CrossPlatform` directory contains the Tauri 2 version for macOS and Windows 11, with a shared interface, business logic, and data format. It is intended to replace the native release over time and provides installers and in-app updates for nontechnical users.

## Installation and updates

Users do not need Git commands or development tools:

1. Open the [latest Releases page](https://github.com/Swiaple/workday-widget/releases/latest).
2. On Windows 11, download the file whose name ends in `x64-setup.exe`.
3. On an Apple silicon Mac, download the `aarch64.dmg`; on an Intel Mac, download the `x64.dmg`.
4. Install version 4 once. Future versions are checked silently at startup. When an update is available, the widget displays an **Update** entry and can download, install, and relaunch from **More Widget Settings**.

Update packages are independently signed, so the app only installs updates published by the project maintainer. Work records, background images, and settings remain on the user's computer and are not uploaded to GitHub.

> **First-install warning:** Current release packages do not yet use an Apple Developer ID certificate or a commercial Windows code-signing certificate. macOS may report that it cannot verify the developer, and Windows SmartScreen may display “Windows protected your PC” during the first installation. In-app update packages already have their own cryptographic signature, but eliminating the operating-system warning requires the relevant commercial certificate.

## Features

- Click the widget to set today's start time, or drag its empty area to move it.
- Save a custom planned work duration once and keep using it until it is changed.
- See the estimated clock-out time and live work progress.
- Clock out immediately with the always-visible button in the lower-right corner.
- The progress runner is off by default. Enable the built-in green running figure in **More Widget Settings**, or upload a GIF, APNG, WebP, PNG, or JPEG as a custom animated progress icon. The icon moves with the current work progress; during overtime, the built-in runner changes along with the red overtime progress.
- Regular time is shown in green. Overtime progress and the status dot gradually deepen in red.
- Clocking out stores the actual end time and total duration.
- Browse monthly records, daily details, and green/red heatmaps.
- Edit historical records and recover from overnight shifts or a forgotten clock-out.
- Keep records permanently with a backup of the previous data file.
- Choose system glass, an original custom image, or a blurred image background, with image cropping and zoom.
- Restore the widget to its last monitor and position.
- Open every panel on the widget's current monitor with a smooth transition.
- Stay at the desktop level without covering normal work windows.
- Check for signed updates automatically and install them inside the app.

## Suggestions and contributions

Ideas for new features, usability improvements, and bug reports are very welcome. Open a topic in [GitHub Issues](https://github.com/Swiaple/workday-widget/issues), or submit a Pull Request if you would like to contribute code. For feature requests, including the use case, expected behavior, operating-system version, and relevant screenshots makes the idea easier to understand and implement.

## Building

### Native macOS 3.5

Requirements:

- macOS 13.0 or later
- Xcode Command Line Tools

Build from the repository root:

```bash
zsh scripts/build.sh
```

The result is created at:

```text
build/打卡时间.app
```

The script uses an ad-hoc local signature. It does not create a notarized Developer ID release.

### Cross-platform 4.x

The `CrossPlatform` project requires Node.js, Rust, and the native build tools for the current platform:

```bash
cd CrossPlatform
npm ci
npm test
npm run tauri build
```

You do not need to cross-compile Windows on a Mac. Pushing an `app-v*` version tag starts GitHub Actions on macOS and Windows runners, tests the shared logic, creates the installers, and generates the `latest.json` manifest used by the in-app updater.

## Usage

- Left-click an empty part of the widget: set the start time.
- Drag an empty part: move the widget without opening the time editor.
- Click the calendar icon: open monthly work history.
- Right-click the widget: open clock-out, work schedule, history, and additional settings.
- Open **More Widget Settings** to choose a background, crop and zoom it, select a progress icon, or check for updates.

## Data and privacy

The app runs locally and does not upload work records or personal images.

Native macOS 3.5 stores records in:

```text
~/Library/Application Support/打卡时间/work-records.json
~/Library/Application Support/打卡时间/work-records.backup.json
```

Cross-platform 4.x uses the operating system's standard application-data directory and keeps an `app-state.json` file plus a previous backup. On its first macOS launch, it imports compatible 3.5 records, the planned duration, custom background, and progress icon.

Back up important records before deleting application data or testing a beta release.

## Project structure

```text
workday-widget/
├── LICENSE
├── README.md
├── README_EN.md
├── .github/workflows/
│   ├── cross-platform-check.yml
│   └── release.yml
├── CrossPlatform/
│   ├── src/
│   ├── src-tauri/
│   ├── package.json
│   └── app-icon.svg
├── Resources/
├── Sources/WorkdayWidget/
├── Tests/
└── scripts/
```

The native macOS source remains available for developers who prefer AppKit. New shared macOS and Windows work lives under `CrossPlatform`.

## Testing

Run the cross-platform shared-logic tests with:

```bash
npm test --prefix CrossPlatform
```

Every relevant push is also compiled on real macOS and Windows GitHub runners. The native Objective-C record-store and settings tests are documented in the Chinese README and run entirely in temporary user directories.

## Sharing the source

You may share the repository or a ZIP of the complete folder. Local dependencies, build artifacts, project-only toolchains, and the private update-signing key are excluded by `.gitignore`.

Never share or commit the update private key. Anyone who has it can sign an update that installed copies would trust.

## Versioning and releases

The native 3.5 version is defined in `Resources/Info.plist`.

For cross-platform 4.x releases, update the version in:

- `CrossPlatform/package.json`
- `CrossPlatform/src-tauri/Cargo.toml`
- `CrossPlatform/src-tauri/tauri.conf.json`

Then push a matching tag such as `app-v4.0.0`. GitHub Actions builds the macOS and Windows installers and publishes the signed updater artifacts.

## License

This project is licensed under the [MIT License](LICENSE). You may use, copy, modify, and distribute it, including for commercial purposes, as long as the copyright and license notice are retained. The software is provided as-is, without warranty.
