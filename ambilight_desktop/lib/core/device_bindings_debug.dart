import 'package:logging/logging.dart';

import '../application/build_environment.dart';
import 'models/config_models.dart';

/// Podrobné logy pro přidání/odebrání zařízení, USB↔Wi‑Fi a rebuild transportů.
/// Logger: `AmbiDeviceBindings` (výchozí root často ukáže INFO).
final _log = Logger('AmbiDeviceBindings');

String _fmtDev(DeviceSettings d) {
  final conn = d.type == 'wifi' ? 'ip=${d.ipAddress}:udp=${d.udpPort}' : 'port=${d.port}';
  return '${d.id}:${d.type}(led=${d.ledCount},ha=${d.controlViaHa}) $conn';
}

/// Jedna řádka — seznam zařízení.
String formatDeviceBindingsList(List<DeviceSettings> ds) =>
    ds.isEmpty ? '<žádné>' : ds.map(_fmtDev).join(' | ');

void traceDeviceBindings(String message) {
  _log.info('[DeviceBindings] $message');
}

/// [Level.FINE] — jen při [ambilightDebugTraceEnabled].
void traceDeviceBindingsDebug(String message) {
  if (!ambilightDebugTraceEnabled) return;
  _log.fine('[DeviceBindings] $message');
}

void traceDeviceBindingsWarning(String message, [Object? e, StackTrace? st]) {
  if (e != null) {
    _log.warning('[DeviceBindings] $message', e, st);
  } else {
    _log.warning('[DeviceBindings] $message');
  }
}

void traceDeviceBindingsSevere(String message, Object e, StackTrace st) {
  _log.severe('[DeviceBindings] $message', e, st);
}

/// Zařízení + stručně segmenty (device_id v segmentech).
void traceConfigBindings(String phase, AppConfig c) {
  final segBrief = c.screenMode.segments
      .map((s) => '${s.deviceId ?? "∅"}@${s.edge}[${s.ledStart}-${s.ledEnd}]')
      .join(', ');
  _log.info(
    '[DeviceBindings] $phase | devices(${c.globalSettings.devices.length}): '
    '${formatDeviceBindingsList(c.globalSettings.devices)} | '
    'segments(${c.screenMode.segments.length}): ${segBrief.isEmpty ? "—" : segBrief}',
  );
}

void traceStripOrphan(String removedDeviceId, String segmentSummary) {
  _log.info(
    '[DeviceBindings] stripOrphan: deviceId=$removedDeviceId nepatří do seznamu zařízení → '
    'segment $segmentSummary: deviceId→null',
  );
}

/// Varování při načtení / aplikaci konfigurace: duplicitní cíle, USB+Wi‑Fi na jednom PC (FW source lock).
void logEspTransportBindingWarnings(AppConfig config) {
  final devs = config.globalSettings.devices;
  if (devs.isEmpty) return;

  final wifiKeys = <String, List<String>>{};
  final serialPorts = <String, List<String>>{};
  for (final d in devs) {
    if (d.controlViaHa) continue;
    if (d.type == 'wifi') {
      final ip = d.ipAddress.trim().replaceAll(',', '.');
      if (ip.isEmpty) continue;
      final key = '$ip:${d.udpPort}';
      wifiKeys.putIfAbsent(key, () => []).add(d.id);
    } else if (d.type == 'serial') {
      final p = d.port.trim();
      if (p.isEmpty) continue;
      serialPorts.putIfAbsent(p, () => []).add(d.id);
    }
  }
  for (final e in wifiKeys.entries) {
    if (e.value.length > 1) {
      _log.warning(
        '[DeviceBindings] Stejný UDP cíl ${e.key} pro více zařízení (${e.value.join(", ")}) — '
        'každý dostane stejný stream; ověř záměr.',
      );
    }
  }
  for (final e in serialPorts.entries) {
    if (e.value.length > 1) {
      _log.warning(
        '[DeviceBindings] Stejný COM port ${e.key} pro více zařízení (${e.value.join(", ")}) — '
        'typicky chyba konfigurace.',
      );
    }
  }

  final hasActiveWifi = devs.any(
    (d) =>
        !d.controlViaHa &&
        d.type == 'wifi' &&
        d.ipAddress.trim().isNotEmpty,
  );
  final hasActiveSerial = devs.any(
    (d) =>
        !d.controlViaHa &&
        d.type == 'serial' &&
        d.port.trim().isNotEmpty,
  );
  if (hasActiveWifi && hasActiveSerial) {
    _log.warning(
      '[DeviceBindings] V konfiguraci jsou aktivní Wi‑Fi i USB výstupy. '
      'Firmware lampy po sériové komunikaci na stejném ESP ignoruje UDP ~2,5 s (source lock v ambilight.c). '
      'Pro stabilní stream použij jednu cestu nebo dva fyzicky oddělené kontrolery — viz repo context/ESP_UDP_TRANSPORT_NOTES.md.',
    );
  }
}
