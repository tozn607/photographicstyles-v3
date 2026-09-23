# Photographic Styles v3 (PhotoStyle)

[![Build & Release](https://github.com/tozn607/photographicstyles-v3/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/tozn607/photographicstyles-v3/actions/workflows/build-and-release.yml)
[![Version](https://img.shields.io/badge/version-v1.0-blue.svg)](https://github.com/tozn607/photographicstyles-v3)
[![Author](https://img.shields.io/badge/author-@tozn607-orange.svg)](https://github.com/tozn607)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-black.svg)](https://github.com/tozn607/photographicstyles-v3)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A native Swift application and command-line utility for **macOS** and **iOS** that enables native Apple Photos **Photographic Styles**, **Photographic Styles 3 (Texture + Grain)**, and **Apple Portrait Mode** on imported photos.

**Version**: `v1.0`  
**Author**: **@tozn607**  
**Repository**: [https://github.com/tozn607/photographicstyles-v3](https://github.com/tozn607/photographicstyles-v3)  
**Download**: [Releases Tab](https://github.com/tozn607/photographicstyles-v3/releases)
### Note: .ipa file is currently broken.

---

## Overview

<img width="1658" height="1072" alt="Screenshot 2026-09-23 at 17 24 33" src="https://github.com/user-attachments/assets/515b6389-21ba-4f96-9396-c6da85fb371a" />


PhotoStyle takes any picture (JPEG, PNG, HEIC, TIFF, WebP, RAW) and generates Apple's native auxiliary data structures and ISOBMFF container items without baking changes into the primary image pixels. When imported into Apple Photos on iOS 18+ or macOS Sequoia+, Apple Photos recognizes the image as an Apple-captured photo and unlocks its full suite of interactive adjustment controls:

- **Photographic Styles (Rust)**: Unlocks the 2D Tone, Color, and Palette control pad (as introduced on iPhone 16 / 17) .
- **Photographic Styles 3 (Texture + Grain)**: Injects Standard `texture_styles` metadata, enabling live Texture and Film Grain sliders (as introduced on iPhone Duo / iPhone 18 Pro).
- **Apple Portrait Mode (Rust)**: Generates editable depth maps and disparity graphs for real-time aperture ($f$-stop) depth-of-field manipulation (requires depth data from Apple/OPPO Portrait mode).

> [!NOTE]
> **Non-destructive editing**: These options write editable metadata and auxiliary layer graphs; the look is **not** baked into the photo's pixels.

---

## Features (Parity with [XDRemux](https://github.com/21Z121Z1/XDRemux) & [XDRemux-Flutter](https://github.com/BeetMan/XDRemux-Flutter))

### 1. Apple Photos Photographic Styles (Rust)
- Constructs the full Apple Photographic Styles ISOBMFF container hierarchy:
  - 30-tile delta map grid (5×6 landscape or 6×5 portrait, 512×512 neutral tiles, `tag:apple.com,2023:photo:aux:styledeltamap`)
  - Linear thumbnail item (`tag:apple.com,2023:photo:aux:linearthumbnail`)
  - Semantic sky matte item (`urn:com:apple:photo:2020:aux:semanticskymatte`)
  - `styleMetadata` binary plist item with the 51,840-byte identity `styleData` lattice (864 blocks × 30 f16 values)
  - Apple MakerNote in EXIF (photo UUID, tag 84 runtime-flags binary plist)
  - *Included in Photographic Styles 3; turn that off to change this.*

### 2. Photographic Styles 3 (Texture + Grain)
- Emits a Standard `texture_styles` item (`tag:apple.com,2026:photo:metadata:texture_styles`) carrying `textureInfo`:
  - `Preset`: `Standard`
  - `CaptureType`: `LF`
  - `CaptureMode`: `Still`
  - `PortType`: `PortTypeBack`
  - `HardwareModel`: `iPhone 18 Pro`
  - `TextureStylePeopleDataVersion`: `3`
  - `FilmGrainSeed`: Deterministic hash derived from the image path (or user-specified seed)
- Injects 12 native Apple semantic part-matte placeholders (`tag:apple.com,2026:photo:aux:semantic...`):
  - `nose`, `skin v2`, `non-face skin`, `lips`, `teeth v2`, `person`, `glasses v2`, `eyebrows`, `tattoo`, `hands`, `ears`, `face skin`.
- Selects Apple Standard output and disables GPU encoding.

### 3. Apple Portrait Mode (Rust)
- Injects editable Apple Portrait depth and disparity data for Apple Photos, allowing interactive aperture ($f$-stop) adjustments.

---

## App Interface (macOS & iOS)

The SwiftUI application features an Apple Human Interface Guidelines-compliant UI:
- **Drag & Drop**: Drop single files or folders directly into the processing window.
- **Photos Library Picker**: Select photos directly from your system photo library.
- **Conversion Settings**: Toggle Photographic Styles, PS3, and Portrait Mode with real-time dependency handling.
- **Batch Processing**: Convert multiple photos asynchronously with queue management.
- **Photo Inspector**: Inspect input vs. output dimensions, file sizes, and verified container features.
- **Footer**: Displays `PhotoStyle v1.0 • Author: @tozn607`.

---

## CLI Usage

PhotoStyle provides a standalone command-line tool `photostyle`:

```bash
# Print version and author
photostyle --version
# Output: PhotoStyle v1.0 • Author: @tozn607 (Core 0.4.2)

# Convert with Photographic Styles 3 (Texture + Grain)
photostyle input.jpg -o styled.heic --ps3

# Convert with Photographic Styles only
photostyle input.jpg -o styled.heic --styles

# Convert with Portrait Mode
photostyle input.jpg -o portrait.heic --portrait

# Combine PS3 and Portrait Mode
photostyle input.jpg -o output.heic --ps3 --portrait

# Inspect an existing HEIC container
photostyle --inspect output.heic

# Run the 18 automated self-tests
photostyle --test
```

### CLI Command Options
```
Usage:
  photostyle <input-path> [options]

Features:
  --styles       Apple Photos Photographic Styles (Rust)
                 Generates editable Photographic Styles graph (tone/color/palette)
  --ps3          Photographic Styles 3 (texture + grain)
                 Injects Standard texture_styles metadata + 12 semantic part mattes.
                 Automatically includes and enables --styles.
  --portrait     Apple Portrait Mode (Rust)
                 Generates editable Apple Portrait depth & disparity graph

Options:
  -o, --output <path>    Output HEIC file path (default: <input-stem>_photostyle.heic)
  --grain-seed <seed>    Custom film grain seed (uint64, default: auto from path)
  --inspect <path>       Inspect ISOBMFF metadata and Apple Photos feature items
  --test                 Run automated self-tests and validation suite
  -h, --help             Show help information
  -v, --version          Print PhotoStyle version and author
```

---

## Building from Source

### Prerequisites
- macOS 14.0+ (Sonoma or Sequoia)
- Xcode 15.0+ or Command Line Tools
- Swift 5.10+
- Rust 1.75+ (`rustc` and `cargo`)

### 1. Build and Run via SwiftPM
```bash
git clone https://github.com/tozn607/photographicstyles-v3.git
cd photographicstyles-v3

# Run the test suite
swift run photostyle --test

# Run the SwiftUI app
swift run PhotoStyleApp

# Build optimized release binaries
swift build -c release
```

### 2. Open in Xcode (macOS & iOS)
```bash
open PhotoStyle.xcworkspace
```
Select the **PhotoStyleApp** scheme and target **My Mac** or any **iOS Simulator / Device**.

---

## Verification & Self-Test Suite

Run the built-in automated test suite:
```bash
swift run photostyle --test
```

Output:
```
========================================
Running PhotoStyle Self-Test Suite
========================================
  ✓ PASS: Core library version check
  ✓ PASS: App version check
  ✓ PASS: Author check
  ✓ PASS: Deterministic grain seed generation
  ✓ PASS: JPEG Conversion with PS3 succeeds
  ✓ PASS: JPEG Output verified for Photographic Styles
  ✓ PASS: JPEG Output verified for PS3 texture + grain
  ✓ PASS: Output carries texture_styles metadata URI
  ✓ PASS: Output carries styledeltamap auxiliary grid
  ✓ PASS: Output carries 12 semantic part mattes
  ✓ PASS: PNG Conversion with PS3 succeeds
  ✓ PASS: PNG Output carries Photographic Styles
  ✓ PASS: PNG Output carries PS3
  ✓ PASS: JPEG Conversion with Styles 1 succeeds
  ✓ PASS: Styles 1 Output verified for Styles
  ✓ PASS: Styles 1 Output does NOT carry PS3
  ✓ PASS: Styles 1 output carries styledeltamap
  ✓ PASS: Styles 1 output omits texture_styles
========================================
Test Results: 18/18 passed.
========================================
```

---

## CI/CD Workflow

The repository includes a GitHub Actions workflow (`.github/workflows/build-and-release.yml`) that automates:
- **macOS Build**: Builds the Rust core, runs the 18-step test suite, compiles `PhotoStyleApp` and `photostyle` CLI, bundles `PhotoStyle.app`, and uploads `PhotoStyle-macOS-v1.0.zip`.
- **iOS Build**: Compiles the Rust core for `aarch64-apple-ios`, builds `PhotoStyleApp` for iOS with `xcodebuild`, packages `Payload/PhotoStyleApp.app`, ad-hoc codesigns it, and uploads `PhotoStyle-iOS-v1.0.ipa`.
- **Automated Releases**: Automatically creates or updates the GitHub Release with the newly built `PhotoStyle-macOS-v1.0.zip` and `PhotoStyle-iOS-v1.0.ipa`.

---

## Credits & Acknowledgements

- **Author**: [@tozn607](https://github.com/tozn607)
- **Special Thanks & Core Engine Credits**:
  - [**XDRemux**](https://github.com/21Z121Z1/XDRemux) by [@21Z121Z1](https://github.com/21Z121Z1) — Original research, reverse engineering, and implementation of Apple Photos ISOBMFF metadata algorithms, Photographic Styles lattice construction, and auxiliary stream grafting.
  - [**XDRemux-Flutter**](https://github.com/BeetMan/XDRemux-Flutter) by [@BeetMan](https://github.com/BeetMan) — Cross-platform UI architecture and mobile reference application for XDRemux.
- **License**: MIT
