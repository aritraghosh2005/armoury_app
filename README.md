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

Designed for offline resilience and high-density operation, Armoury uses an on-device SQLite store for immediate reads and writes. Supabase Auth email/password accounts identify users and register their devices. Sign-up requires an emailed one-time code, and new accounts then wait for admin approval before accessing inventory. Approved users synchronize the shared inventory automatically while the app is active. Config downloads one ZIP containing a CSV inventory and its photos; remotely deleted records can be restored from Archive for seven days.

The first launch imports the starter inventory bundled in `assets/initial_data/current_components.zip` into local SQLite through the same repository path used by normal component creation. It copies the included photos into app-private storage and queues those rows for synchronization. Existing local catalogs are never reseeded or overwritten.

The app syncs the shared catalog through Supabase. SQLite remains the immediate local store, so previously approved accounts can browse their cached inventory offline and queued changes sync when Supabase is reachable. Supabase Auth registers the installation and identifies the person sending changes. New users confirm their email with a six-digit OTP; this verifies address ownership but does not approve access. The app checks approval while users wait and when they return. Viewers can browse; editors can manage components and the archive. One server-configured account has Admin access and can approve accounts, disable access, and assign View or View & Edit. Changes are applied to the latest server record, and server-accepted deletes are final. The Config pane shows recent shared activity.

---

## Key Features

- **⚡ Offline-First Shared Catalog**: Reads and writes use local SQLite immediately; queued changes synchronize with the central catalog when online.
- **🖥️ Cyber-Tactical HUD Aesthetics**: Monospaced typography, optical glass morphing slabs, pure OLED black backgrounds, and subtle scanline aesthetics.
- **📦 4 Structured Workspaces (Spaces)**: Logical partitioning into **Home (Team Orcus)**, **Crate**, **Toolkit**, and **Cupboard**.
- **🔍 Instant Top Search HUD**: Local fuzzy filtering by title, subcategory, component ID, and domain categories (*Mechanical*, *Electrical*, *Others*).
- **📸 Local Media & Photo Attachments**: Attach reference schematics, component photos, and pinout diagrams directly to individual records.
- **🗄️ Inventory Download**: Download one ZIP containing a CSV list of active inventory details (including creation and latest-update timestamps) and the referenced component photos.
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

### Inventory Download and Archive

Open Config and choose **DOWNLOAD INVENTORY + PHOTOS (.ZIP)** to save a package containing `inventory.csv` and an `images/` folder. The CSV includes relative photo-file references and does not expose internal component IDs. Deleted components move to **Archive** for seven days; the archive overview shows only name and quantity and provides restore and permanent-delete actions. The app syncs shared inventory between devices when online and continues accepting local changes offline.

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
├── assets/
│   ├── initial_data/      # Bundled starter inventory archive
│   └── res/               # Logo artwork
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── database/      # SQLite provider, DAOs, schema migrations
│   │   ├── filters/       # Inventory query rules
│   │   ├── repositories/  # Repository contracts and local implementations
│   │   ├── sync/          # API client, queued-operation pusher, change-feed puller, and coordinator
│   │   └── theme.dart
│   ├── models/            # Domain entities and value types
│   ├── providers/
│   │   ├── app_providers.dart # Infrastructure composition
│   │   └── viewmodels/    # Riverpod state and application orchestration
│   ├── screens/           # Auth gate and primary app screens
│   ├── services/          # Supabase Auth, starter data, and backup services
│   └── widgets/           # Reusable presentation components
├── backend/               # Legacy FastAPI reference; not used by the Flutter app
├── test/                  # Flutter unit and widget regression tests
├── compose.yaml           # Legacy backend reference; not the production stack
└── README.md
```

The Flutter client follows MVVM: screens and widgets render state and send user actions to Riverpod ViewModels; repositories and DAOs own local inventory access; Supabase provides hosted Auth, Postgres, Storage, and RPC operations. The `backend/` and Compose files are legacy reference code only and are not used or deployed by the app.

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

   To test shared sync locally, run `npx supabase start`. Local confirmation messages appear in the Mailpit URL shown by `npx supabase status`; open it to read the OTP. For an Android emulator, build/run with `--dart-define=SUPABASE_URL=http://10.0.2.2:55421` and `--dart-define=SUPABASE_PUBLISHABLE_KEY=<local-publishable-key>`. For a physical device, replace `10.0.2.2` with the development computer's LAN IPv4 address and allow the ports through Windows Firewall. A build without these values stays local-only.

### Central Backend Deployment

Supabase Auth, Postgres, and private Storage are the central backend. Local development uses the Supabase CLI and Docker Desktop; production uses a hosted Supabase project. Apply the tracked schema with `npx supabase link --project-ref <project-ref>` and `npx supabase db push`. Enable email/password sign-up and email confirmation in Supabase Auth. Set the Confirm signup email template to include `{{ .Token }}` so users receive the numeric code entered in Armoury. The bootstrap admin allowlist is enforced by a server-side migration for `aritraghosh.ag2005@gmail.com`, and the profile is promoted only after Supabase records that the email as confirmed. For public sign-ups on hosted Supabase, configure custom SMTP: Supabase's default sender is restricted to project-team email addresses and is limited to two messages per hour. Local Supabase captures confirmation messages in Mailpit.

For password recovery, also configure the hosted project's **Authentication > SMTP Settings** with the SMTP credentials for the verified Resend domain. Verifying the domain in Resend alone does not configure Supabase Auth to send mail. In **Authentication > Email Templates > Reset Password**, use the `{{ .Token }}` variable for the six-digit code that Armoury asks the user to enter; the default reset link is not the code-entry flow used by the app. Local reset messages are captured in Mailpit; the local recovery template is `supabase/templates/recovery.html`.

Release builds embed only the hosted `SUPABASE_URL` and its public publishable key using `--dart-define` (or protected build-pipeline variables). New accounts confirm email and remain pending until approved; Supabase policies and RPCs enforce viewer/editor/admin roles and registered-device checks. Users install and open the APK without entering a URL or credentials. Keep FastAPI/Compose files as legacy until the Supabase migration is fully verified; they are not the app's production backend.

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
> **A:** Install the app, create an account with email and password, enter the emailed OTP, and wait for approval. Once approved, the app synchronizes the shared inventory in the background.

#### Q: Can I install this on Windows or macOS?
> **A:** Yes. The application is built using standard Flutter architecture. You can compile for Windows using `flutter build windows` (requires Visual Studio with C++ tools).

#### Q: Where are photos stored on device?
> **A:** Images are stored locally for offline use and synchronized to the central service. CSV exports contain the inventory list, not image files.

---

## Team Orcus

Developed with precision by **Team Orcus**.  
For questions, bug reports, and contributions, open an issue on the [GitHub Repository](https://github.com/aritraghosh2005/armoury_app).
