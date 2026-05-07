/// Kam má směřovat dostupnost PC Health v UI a jako výchozí režim (desktopové builds).
///
/// Na **macOS** je monitoring vypnutý — uživatel ho nevidí a `pchealth` se přemapuje na `light`.
/// Ve **flutter test** (`FLUTTER_TEST=true`) zůstává zapnuto i na Macu kvůli golden/unit testům.
export 'pc_health_platform_support_stub.dart'
    if (dart.library.io) 'pc_health_platform_support_io.dart';
