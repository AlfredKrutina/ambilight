# AmbiLight

**AmbiLight** is a desktop-driven ambient lighting system: the PC samples the screen, audio, or other color sources, then streams RGB data to one or more LED controllers (typically **ESP32-C3** firmware over **USB serial** or **Wi‑Fi UDP**). This repository is a **monorepo** that holds the cross-platform **Flutter desktop client**, planning documents, and a large **reference tree** (legacy Python UI, ESP-IDF projects, and bundled third-party sources).

The primary application you build and run is under **`ambilight_desktop/`**.

---

## What’s in this repository

| Area | Path | Purpose |
|------|------|---------|
| **Flutter desktop app** | [`ambilight_desktop/`](ambilight_desktop/) | Main UI: settings, wizards, engine (screen / music / Spotify), serial & UDP transports, system tray, hotkeys, autostart. Targets **Windows**, **Linux**, and **macOS** (no Android/iOS in this folder by design). |
| **Run & platform notes** | [`ambilight_desktop/README_RUN.md`](ambilight_desktop/README_RUN.md) | Commands, SDK versions, Spotify token storage on Windows, tray/window behavior, Linux X11 vs Wayland, macOS permissions. |
| **ESP / protocol details** | [`ambilight_desktop/README.md`](ambilight_desktop/README.md) | Serial handshake, frame layout, UDP packet shape, baud rate, monitor index conventions, Windows capture implementation notes. |
| **Planning & audits** | [`context/`](context/) | Master plan, gap analysis vs PyQt, UI layout notes, agent prompts, permission overview ([`context/README_PERMISSIONS.md`](context/README_PERMISSIONS.md)). |
| **Reference firmware & Python** | `led_strip_monitor_pokus - Copy/` | ESP-IDF projects (e.g. `esp32c3_firmware/main/ambilight.c`), older PyQt distribution, and vendored SDK trees. **Source of truth for wire protocol** used by the Flutter client is documented in `ambilight_desktop/README.md` and implemented in that firmware file. |

> **Note:** The `led_strip_monitor_pokus - Copy/` directory is bulky and includes many upstream `LICENSE` files from ESP-IDF and other vendors. For day-to-day work on the desktop app, stay in **`ambilight_desktop/`** and **`context/`**.

---

## How it works (high level)

1. **Configuration**  
   The app loads a JSON-backed config (device list, global settings, screen/music/Spotify options). Models and persistence live under `ambilight_desktop/lib/` (e.g. config repository and golden tests in `test/`).

2. **Color pipeline**  
   An **engine** selects the active mode (e.g. screen sampling, music FFT / beat features, Spotify metadata-driven colors), runs smoothing and zone/segment mapping, and produces per-LED RGB values.

3. **Output**  
   For each configured device, a **transport** sends frames:
   - **Serial:** handshake and framed payloads compatible with the ESP firmware (see [`ambilight_desktop/README.md`](ambilight_desktop/README.md)).
   - **UDP:** brightness byte plus RGB triplets as expected by the same firmware family.

4. **Reconnect**  
   If a device is not ready at startup, the client **retries connection on a timer** (on the order of every few seconds) until the link succeeds.

5. **Native capture**  
   Screen capture uses a **Flutter `MethodChannel`** (`ambilight/screen_capture`) with platform-specific implementations (e.g. Windows GDI **BitBlt** in the Windows runner). Linux uses **X11** (`XGetImage`); pure Wayland without XWayland may be unsupported—see [`ambilight_desktop/README_RUN.md`](ambilight_desktop/README_RUN.md).

6. **OS integration**  
   Tray icon (including dynamic icon by mode), window hide-on-close, global hotkeys, launch-at-login, and optional Spotify OAuth use plugins documented in run notes and [`context/README_PERMISSIONS.md`](context/README_PERMISSIONS.md).

For a feature-level checklist vs the older PyQt stack, see [`context/PROJECT_STATE_AUDIT.md`](context/PROJECT_STATE_AUDIT.md) and [`context/FLUTTER_VS_PYQT_GAP_ANALYSIS.md`](context/FLUTTER_VS_PYQT_GAP_ANALYSIS.md).

---

## Requirements

- **Flutter** stable channel with **desktop** enabled (Windows, Linux, or macOS).
- The project is tested in CI against an interface similar to **Flutter 3.41+** / **Dart 3.11+** (see workflow below). Your SDK should be in that range or newer stable.

---

## Quick start

```bash
cd ambilight_desktop
flutter pub get
flutter analyze
flutter test
flutter run -d windows    # or: linux | macos
```

Release builds:

```bash
flutter build windows
flutter build linux
flutter build macos
```

More detail (Linux packages for CI, macOS entitlements, icon regeneration, PowerShell pitfalls): **[`ambilight_desktop/README_RUN.md`](ambilight_desktop/README_RUN.md)**.

---

## Continuous integration

GitHub Actions workflow **[`.github/workflows/ambilight_desktop.yml`](.github/workflows/ambilight_desktop.yml)** runs on **Ubuntu**, **Windows**, and **macOS**:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build <platform> --debug` (validates native toolchains)

Triggers are limited to changes under `ambilight_desktop/`, the workflow file, and this root `README.md`.

---

## Project layout (`ambilight_desktop/lib/` — conceptual)

| Topic | Typical location |
|-------|------------------|
| App orchestration | `application/ambilight_app_controller.dart` |
| Engine & modes | `engine/` |
| Screen capture | `features/screen_capture/` |
| Music / audio | `services/music/` |
| Spotify | `features/spotify/` |
| Settings UI (multiple tabs) | `ui/settings/` |
| Wizards | `ui/wizards/` |
| Device / serial / UDP | `data/` and related services |

Tests live in **`ambilight_desktop/test/`**.

---

## Contributing

1. Open a PR against the default branch; keep changes focused (the Flutter app is under `ambilight_desktop/`).
2. Run **`flutter analyze`** and **`flutter test`** locally before pushing.
3. If you touch permissions, tray, or capture, update or cross-check **`ambilight_desktop/README_RUN.md`** and **`context/README_PERMISSIONS.md`**.

---

## Documentation index

| Document | Description |
|----------|-------------|
| [`ambilight_desktop/README_RUN.md`](ambilight_desktop/README_RUN.md) | Runbook and OS-specific behavior |
| [`ambilight_desktop/README.md`](ambilight_desktop/README.md) | Wire protocol, Windows capture, monitor indexing |
| [`context/DESKTOP_TARGETS.md`](context/DESKTOP_TARGETS.md) | Why only desktop platforms in this package |
| [`context/AmbiLight-MASTER-PLAN.md`](context/AmbiLight-MASTER-PLAN.md) | Roadmap and waves |
| [`context/PROJECT_STATE_AUDIT.md`](context/PROJECT_STATE_AUDIT.md) | Status table vs master plan |
| [`context/FLUTTER_VS_PYQT_GAP_ANALYSIS.md`](context/FLUTTER_VS_PYQT_GAP_ANALYSIS.md) | Parity gaps with the legacy UI |

---

## Language note

The root **README** is maintained in **English** for public contributors. Some secondary docs under `ambilight_desktop/` and `context/` may still be in Czech; the links above point to the most up-to-date technical material regardless of language.

---

*AmbiLight — desktop client for ambient LED control; firmware-oriented protocol and multi-device support.*
