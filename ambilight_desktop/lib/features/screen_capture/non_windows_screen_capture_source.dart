import 'package:logging/logging.dart';

import 'screen_capture_source.dart';
import 'screen_frame.dart';

final Logger _log = Logger('ambilight.screen_capture');

/// Web / neznámá platforma — bez nativního kanálu.
class NonWindowsScreenCaptureSource implements ScreenCaptureSource {
  bool _warned = false;

  void _warnOnce() {
    if (_warned) return;
    _warned = true;
    _log.warning('Screen capture: web nebo nepodporovaná platforma (stub).');
  }

  @override
  Future<ScreenFrame?> captureFrame(int monitorIndex, {String? windowsCaptureBackend}) async {
    _warnOnce();
    return null;
  }

  @override
  Future<List<MonitorInfo>> listMonitors() async {
    _warnOnce();
    return const <MonitorInfo>[];
  }

  @override
  Future<ScreenSessionInfo> getSessionInfo() async {
    _warnOnce();
    return ScreenSessionInfo.unknown;
  }

  @override
  Future<bool> requestScreenCapturePermission() async => true;

  @override
  void dispose() {}
}
