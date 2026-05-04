# Platforma — resume / sleep / tray (Fáze 6)

| Událost | Akce |
|---------|------|
| `AppLifecycleState.resumed` | `onDesktopAppResumed()` — reset `setIgnoreMouseEvents(false)`, obnovení tray menu/tooltip |
| `AppLifecycleState.resumed` | `AmbilightAppController.refreshCaptureSessionInfo()` — aktualizace diagnostiky snímání |
| Dvojklik tray | Otevření nastavení (existující logika `_TrayTapListener`) |
| Pravý klik tray | Kontextové menu |

**Manuální ověření:** viz `SHIP_READY_CRASH_RESILIENCE_PLAN.md` §12 (Windows checklist).
