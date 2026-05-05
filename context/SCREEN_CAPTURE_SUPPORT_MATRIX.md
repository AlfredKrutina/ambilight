# Screen capture — matice podpor (P5)

Kanál: `ambilight/screen_capture` (`listMonitors`, `capture`, `sessionInfo`, `requestPermission`).

| OS | Session / prostředí | Capture | Poznámka |
|----|---------------------|---------|----------|
| **Windows** | Win32 desktop | GDI `BitBlt` | Implementováno v `windows/runner/screen_capture_channel.cpp`. HDR / exclusive fullscreen mohou odlišně chovat. |
| **Linux** | X11 + `DISPLAY` | `XGetImage` + XRandR `XRRGetMonitors` | `linux/runner/screen_capture_linux.cc`. Index `0` = sjednocený bounding box, `1..n` = monitory. |
| **Linux** | Wayland (čistý, bez XWayland) | — | `sessionInfo` hlásí `wayland_present`; `XOpenDisplay` typicky selže bez X serveru. **PipeWire / xdg-desktop-portal** zatím nejsou v tomto repu. |
| **Linux** | XWayland pod Waylandem | často X11 stejná cesta | Záleží na kompozitoru; `XGetImage` může selhat nebo snímat jen X klienty. |
| **macOS** | TCC „Screen Recording“ | viz `context/macos_screen_capture_reference.swift` | Po `flutter create --platforms=macos` přidej Swift do targetu Runner a zavolej `ScreenCaptureChannel.register`. Uživatel musí povolení v **System Settings → Privacy & Security → Screen Recording**. |
| **Web** | — | stub | `NonWindowsScreenCaptureSource`, žádný nativní kanál. |

**Fallback (Dart):** při chybě kanálu `captureFrame` vrací `null`; `MethodChannelScreenCaptureSource.lastError` nese text z `PlatformException`. Engine dál může používat černý rámec (P6).

**Build Linux:** vyžaduje `linux/flutter/ephemeral/generated_config.cmake` z Flutter nástroje (`flutter pub get` / `flutter build linux` na Linuxu). Soubor `linux/flutter/generated_plugins.cmake` přepíše `flutter pub get` podle pluginů.
