# AmbiLight

**AmbiLight** is a desktop-driven ambient lighting system: the PC samples the screen, audio, or other color sources, then streams RGB data to one or more LED controllers (typically **ESP32-C3** firmware over **USB serial** or **Wi‑Fi UDP**). This repository is a **monorepo** that holds the cross-platform **Flutter desktop client**, planning documents, and a large **reference tree** (legacy Python UI, ESP-IDF projects, and bundled third-party sources).

The primary application you build and run is under **`ambilight_desktop/`**.

**Quick downloads (pre-built desktop + firmware mirror):**  
You can grab Windows ZIP, macOS DMG, Linux tarball, and ESP firmware from the **[GitHub Pages download site](https://alfredkrutina.github.io/ambilight/)** — same files as the latest `desktop-v*` release, hosted for easy sharing.

---

## What’s in this repository

| Area | Path | Purpose |
|------|------|---------|
| **Flutter desktop app** | [`ambilight_desktop/`](ambilight_desktop/) | Main UI: settings, wizards, engine (screen / music / Spotify), serial & UDP transports, system tray, hotkeys, autostart. Targets **Windows**, **Linux**, and **macOS** (no Android/iOS in this folder by design). |
| **Run & platform notes** | [`ambilight_desktop/README_RUN.md`](ambilight_desktop/README_RUN.md) | Commands, SDK versions, Spotify token storage on Windows, tray/window behavior, Linux X11 vs Wayland, macOS permissions. |
| **ESP / protocol details** | [`ambilight_desktop/README.md`](ambilight_desktop/README.md) | Serial handshake, frame layout, UDP packet shape, baud rate, monitor index conventions, Windows capture implementation notes. |
| **Planning & audits** | [`context/`](context/) | Master plan, gap analysis vs PyQt, UI layout notes, agent prompts, permission overview ([`context/README_PERMISSIONS.md`](context/README_PERMISSIONS.md)). Flutter↔ESP provoz: [`context/ESP_UDP_TRANSPORT_NOTES.md`](context/ESP_UDP_TRANSPORT_NOTES.md), [`context/REPRO_MATRIX_FLUTTER_ESP.md`](context/REPRO_MATRIX_FLUTTER_ESP.md), [`context/HA_AMBILIGHT_COEXIST.md`](context/HA_AMBILIGHT_COEXIST.md). |
| **Reference firmware & Python** | `led_strip_monitor_pokus - Copy/` | **Aktivní FW:** `esp32c3_lamp_firmware/main/ambilight.c`. Starý monitor strom je v **`esp32c3_monitor_firmware_ARCHIVE/`** (jen lokálně, v `.gitignore`). PyQt + další reference vedle. Protokol: `ambilight_desktop/README.md`. |

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
   - **Smart Home (optional):** **Home Assistant** `light.turn_on` with `rgb_color` (URL + long-lived token in **Settings → Smart Home**). The HA token is **not** stored inside `default.json`; it is written to application support as `ha_long_lived_token.txt` (same pattern as Spotify tokens). **Apple HomeKit** on **macOS** uses a native `MethodChannel` (`ambilight/homekit`). **Google Home** has no supported local desktop API—use Home Assistant’s [Google Assistant](https://www.home-assistant.io/integrations/google_assistant/) integration and control the same lights through HA.

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

### Firmware (ESP-IDF) and GitHub Pages

Workflow **[`.github/workflows/firmware-pages.yml`](.github/workflows/firmware-pages.yml)** builds **`led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/`** (ESP-IDF **v5.5.x** per `sdkconfig`, image **`espressif/idf:v5.5.1`**) and deploys **`firmware/latest/manifest.json`** plus bootloader, partition table, and **`ambilight_esp32c6.bin`** via **GitHub Actions → GitHub Pages** (`upload-pages-artifact` + `deploy-pages`).

**One-time setup in this repository:** **Settings → Pages → Build and deployment → Source:** choose **GitHub Actions** (not “Deploy from a branch”). If Source stays on **“Deploy from a branch”** or Pages is disabled, the **`deploy`** job fails with **`HttpError: Not Found (404)`** when creating the deployment — the build job can still succeed. Fix: **Repository → Settings → Pages** (`https://github.com/<owner>/<repo>/settings/pages`), set **Source** to **GitHub Actions**, save, then **re-run** the failed workflow or push again.

After deploy succeeds, the site is at **`https://<owner>.github.io/<repo>/`** (manifest: **`…/firmware/latest/manifest.json`**). If your org uses deployment protection rules, approve the **`github-pages`** environment the first time it runs (**Settings → Environments → github-pages**).

The Flutter app (**Settings → Firmware**) can fetch that manifest, cache binaries, flash over **USB** (`esptool` on `PATH`), or trigger **HTTPS OTA** with UDP **`OTA_HTTP <url>`** to the device (same URL as in the manifest). The lamp firmware also accepts MQTT **`alfred/devices/<deviceId>/ota`** with the URL as payload. The first move from an older **factory-only** partition table to **two-slot OTA** still needs a **full USB flash** (partition table + erase) once.

This partition layout targets **4 MB SPI flash** (`sdkconfig` + `partitions.csv` are aligned). Boards with only 2 MB need a smaller custom partition table and matching `CONFIG_ESPTOOLPY_FLASHSIZE_*` before the image will link or boot reliably.

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
| Firmware updates (manifest, esptool, OTA) — **legacy Flutter UI** | `features/firmware_legacy_old_code/` + **Settings → Firmware** |

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
