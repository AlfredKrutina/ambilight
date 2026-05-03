import 'package:logging/logging.dart';

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
