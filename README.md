# ORCUS · ARMOURY

<div align="center">

```
  ____  _____   ____ _   _ ____        _    ____  __  __  ___  _   _ ______   __
 / __ \|  _ \ / ___| | | / ___|      / \  |  _ \|  \/  |/ _ \| | | |  _ \ \ / /
| |  | | |_) | |   | | | \___ \     / _ \ | |_) | |\/| | | | | | | | |_) \ V / 
| |__| |  _ <| |___| |_| |___) |   / ___ \|  _ <| |  | | |_| | |_| |  _ < | |  
 \____/|_| \_\\____|\___/|____/   /_/   \_\_| \_\_|  |_|\___/ \___/|_| \_\|_|  
```

**Tactical Offline Hardware Inventory & Asset Registry Engine**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![Architecture](https://img.shields.io/badge/Architecture-Riverpod%20%2B%20SQLite-blueviolet)](https://riverpod.dev)
[![Status](https://img.shields.io/badge/Build-Release%20Ready-brightgreen)](https://github.com/aritraghosh2005/armoury_app/releases)
[![Theme](https://img.shields.io/badge/Design-Monochrome%20Cyber--HUD-black)](#tactical-design-system)

---

### [⬇️ Download Latest Android APK (v1.0.0)](https://github.com/aritraghosh2005/armoury_app/releases/download/v1.0.0/app-release.apk)
*Ready-to-install Android release binary (`app-release.apk`, ~52 MB)*

---

</div>

## Table of Contents
- [Overview](#overview)
- [Key Features](#key-features)
- [Spaces & Organization](#spaces--organization)
- [Tactical Design System](#tactical-design-system)
- [User Guide](#user-guide)
  - [Download & Installation](#download--installation)
  - [App Walkthrough](#app-walkthrough)
  - [Backup & Restore](#backup--restore)
- [Developer Guide](#developer-guide)
  - [Tech Stack](#tech-stack)
  - [Architecture & Directory Structure](#architecture--directory-structure)
  - [Local Setup & Running](#local-setup--running)
  - [Testing](#testing)
  - [Building for Deployment](#building-for-deployment)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Team Orcus](#team-orcus)

---

## Overview

**Orcus Armoury** is a cyber-tactical offline hardware inventory and component tracking suite engineered for robotics teams, makerspaces, hardware engineers, and tactical gear administrators.

Designed from the ground up for strict offline resilience and high-density operation, Armoury operates without requiring cloud databases, external logins, or remote telemetry. All data is persisted locally in an on-device SQLite relational store with atomic multi-image attachments and one-click ZIP archive portability.

---

## Key Features

- **⚡ Zero-Cloud Offline Resilience**: Fully functional without internet connectivity. Powered by local SQLite 3 with instant query times.
- **🖥️ Cyber-Tactical HUD Aesthetics**: Monospaced typography, optical glass morphing slabs, pure OLED black backgrounds, and subtle scanline aesthetics.
- **📦 4 Structured Workspaces (Spaces)**: Logical partitioning into **Home (Team Orcus)**, **Crate**, **Toolkit**, and **Cupboard**.
- **🔍 Instant Top Search HUD**: Sub-millisecond fuzzy filtering by title, subcategory, component ID, and domain categories (*Mechanical*, *Electrical*, *Others*).
- **📸 Local Media & Photo Attachments**: Attach reference schematics, component photos, and pinout diagrams directly to individual records.
- **🗄️ Portable ZIP Backup & Migration**: Package the entire inventory database and attached images into a portable `.zip` bundle for frictionless backup, recovery, or migration between devices.
- **🌗 Seamless Pixel Dissolve Theme Switching**: Instant toggle between pitch-black OLED Dark Mode and architectural high-contrast Light Mode via a custom GPU pixel-dissolve shader transition.
- **📐 Responsive Sliding Configuration Pane**: Smooth 65% sliding optical glass settings slab with real-time telemetry inspection and database metrics.

---

## Spaces & Organization

The Armoury separates hardware into four dedicated operational namespaces:

| Workspace | Icon | Primary Purpose | Examples |
|---|---|---|---|
| **HOME (`TEAM ORCUS`)** | `[⌂]` | System Telemetry, Global Counts, & Full Master Registry | Summary metrics, total unit counts, master inventory rows |
| **CRATE** | `[▣]` | Structural & Raw Materials | Aluminum extrusions, acrylic sheets, motors, chassis parts |
| **TOOLKIT** | `[⌧]` | Reusable Tools & Diagnostic Gear | Soldering irons, multimeters, wire strippers, torque wrenches |
| **CUPBOARD** | `[≡]` | Consumables, Hardware, & Small Fasteners | M3/M4 hex bolts, heat-shrink tubing, capacitors, terminal blocks |

---

## Tactical Design System

Armoury features a custom design language inspired by military mission avionics and cyberpunk command consoles:

- **Typography**: Google `JetBrains Mono` across all labels, counters, and metadata readouts.
- **OLED Pure Black Palette**: Pitch black (`#000000`) background canvas paired with high-contrast architectural white (`#FFFFFF`) and slate accents (`#0F172A`).
- **Optical Glass Slabs**: Multi-layered backdrop filters with physical borders, inner glow shadows, and dynamic 3D scale transforms.
- **B&W Contrast Indicators**: Pure monochrome status badges and telemetry indicators for distraction-free night and workshop operation.

---

## User Guide

### Download & Installation

#### Requirements
- **Device**: Android 8.0 (API level 26) or higher.
- **Architecture**: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- **Storage**: ~70 MB available space.

#### Step-by-Step Installation
1. Download the latest release:  
   👉 [**Download `app-release.apk`**](https://github.com/aritraghosh2005/armoury_app/releases/download/v1.0.0/app-release.apk)
2. Tap on the downloaded `.apk` file from your Android notifications or File Manager.
3. If prompted with *"For your security, your phone is not allowed to install unknown apps from this source"*:
   - Tap **Settings**.
   - Enable **Allow from this source**.
4. Tap **Install** and open **Armoury**.

### App Walkthrough

1. **Viewing Components**:
   - Swipe horizontally or tap bottom navigation items (`HOME`, `CRATE`, `TOOLKIT`, `CUPBOARD`) to jump between spaces.
2. **Adding Components**:
   - Tap **`+ ADD`** in the subheader.
   - Fill in Component Name, Subcategory, Quantity, Status, Domain (*Mechanical*, *Electrical*, *Others*), and optional photo.
   - Tap **`CONFIRM ENTRY >>`** to store.
3. **Searching & Filtering**:
   - Tap **`SEARCH_`** or **double-tap** anywhere on the header to reveal the Search HUD.
   - Filter by domain buttons or type freeform text to filter results instantly.
4. **Component Management**:
   - Tap any component card to view its detailed HUD sheet.
   - Adjust quantities with `[ - ]` and `[ + ]` or purge depleted entries.

### Backup & Restore

Keep your repository safe across device updates:

1. Tap the **Settings Gear / Reticle Button** in the upper right.
2. The **CONFIG** glass pane slides in from the right.
3. **To Export**:
   - Under **BACKUP & RESTORE**, tap **`EXPORT BACKUP (.ZIP)`**.
   - Choose a target directory in your storage.
   - An archive formatted as `armoury_backup_YYYYMMDD_HHMMSS.zip` is created containing the SQLite database and all attached media.
4. **To Restore**:
   - Tap **`IMPORT BACKUP (.ZIP)`**.
   - Select your `.zip` archive.
   - The app verifies integrity and restores all items and images immediately.

---

## Developer Guide

### Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod`)
- **Database Engine**: [sqflite](https://pub.dev/packages/sqflite) (SQLite 3 C-library bindings)
- **File & Archive IO**: [path_provider](https://pub.dev/packages/path_provider), [archive](https://pub.dev/packages/archive), [file_picker](https://pub.dev/packages/file_picker)
- **Image Handling**: [image_picker](https://pub.dev/packages/image_picker), [cached_network_image](https://pub.dev/packages/cached_network_image)
- **Typography**: [google_fonts](https://pub.dev/packages/google_fonts) (JetBrains Mono)

---

### Architecture & Directory Structure

```
armoury_app/
├── android/               # Native Android Gradle configuration
├── assets/                # Pre-seeded JSON templates & insignia branding
│   ├── data/              # Factory fallback database definitions
│   └── res/               # Logo and wallpaper SVG/PNG assets
├── lib/
│   ├── main.dart          # Entry point, ProviderScope initialization
│   ├── core/              # Foundational styling & utilities
│   │   ├── ascii_art.dart # ASCII title representations
│   │   ├── database.dart  # SQLite schema migrations & DAO operations
│   │   └── theme.dart     # Monochrome Cyber-HUD tokens & typography
│   ├── models/            # Immutable domain models
│   │   ├── component.dart # Component, Namespace, Domain entities
│   │   └── content.dart   # Metadata models
│   ├── providers/         # Riverpod StateNotifiers & ViewModels
│   │   ├── backup_provider.dart
│   │   ├── theme_provider.dart
│   │   ├── tutorial_provider.dart
│   │   └── viewmodels/
│   │       ├── armoury_viewmodel.dart
│   │       └── search_viewmodel.dart
│   ├── screens/           # Core view pages
│   │   ├── app_shell.dart    # Split-slab optical glass root viewport
│   │   ├── home_screen.dart  # Team Orcus telemetry & master list
│   │   └── space_screen.dart # Namespace-filtered space lists
│   ├── services/          # Pure Dart infrastructure services
│   │   └── backup_service.dart # ZIP packager & unpacker engine
│   └── widgets/           # Atomic, tactical reusable UI components
│       ├── animated_orcus_logo.dart
│       ├── bottom_nav_bar.dart
│       ├── component_card.dart
│       ├── new_component_sheet.dart
│       ├── optical_glass_slab.dart
│       ├── pixel_theme_transition.dart
│       ├── settings_glass_pane.dart
│       ├── tactical_settings_button.dart
│       ├── terminal_button.dart
│       └── top_search_bar.dart
├── test/                  # Automated unit and widget regression tests
│   ├── backup_service_test.dart
│   ├── pixel_theme_transition_test.dart
│   └── widget_test.dart
├── pubspec.yaml           # Dependencies and build settings
└── README.md              # Project documentation
```

---

### Local Setup & Running

#### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.13.2)
- Android SDK / Platform Tools with USB Debugging enabled

#### Instructions
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/aritraghosh2005/armoury_app.git
   cd armoury_app
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on Connected Device / Emulator**:
   ```bash
   flutter run
   ```

---

### Testing

The repository maintains automated test suites covering backup ZIP round-trips, pixel shader rendering, and app shell user interactions:

```bash
# Run all unit and widget tests
flutter test

# Run static analysis and linting
flutter analyze
```

---

### Building for Deployment

#### Generate Release APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```
The output binary will be created at:
`build/app/outputs/flutter-apk/app-release.apk`

#### Generate Android App Bundle (AAB for Google Play)
```bash
flutter build appbundle --release
```
The output bundle will be created at:
`build/app/outputs/bundle/release/app-release.aab`

---

## Troubleshooting & FAQ

#### Q: How do I transfer my inventory from an old phone to a new phone?
> **A:** On the old phone, open Settings (`[⌂] ESC`) -> tap **EXPORT BACKUP (.ZIP)**. Send the generated `.zip` file via Bluetooth, Google Drive, or USB cable to the new phone. On the new phone, tap **IMPORT BACKUP (.ZIP)** and select the file.

#### Q: Can I install this on Windows or macOS?
> **A:** Yes. The application is built using standard Flutter architecture. You can compile for Windows using `flutter build windows` (requires Visual Studio with C++ tools).

#### Q: Where are photos stored on device?
> **A:** Images are stored in the application's secure documents directory (`path_provider`). When an export `.zip` is created, images are packaged alongside the database.

---

## Team Orcus

Developed with precision by **Team Orcus**.  
For questions, bug reports, and contributions, open an issue on the [GitHub Repository](https://github.com/aritraghosh2005/armoury_app).
