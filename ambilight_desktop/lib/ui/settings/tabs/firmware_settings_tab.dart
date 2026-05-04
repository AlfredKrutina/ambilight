import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/config_models.dart';
import '../../../data/udp_device_commands.dart';
import '../../../services/led_discovery_service.dart';
import '../../../features/firmware_legacy_old_code/esptool_flash_runner.dart';
import '../../../features/firmware_legacy_old_code/firmware_manifest.dart';
import '../../../features/firmware_legacy_old_code/firmware_update_service.dart';
import '../../layout_breakpoints.dart';

/// Stažení buildů z webu (manifest) a flash přes USB (esptool) nebo OTA přes Wi‑Fi (UDP).
class FirmwareSettingsTab extends StatefulWidget {
  const FirmwareSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onGlobalChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<GlobalSettings> onGlobalChanged;

  @override
  State<FirmwareSettingsTab> createState() => _FirmwareSettingsTabState();
}

class _FirmwareSettingsTabState extends State<FirmwareSettingsTab> {
  late final TextEditingController _manifestUrlCtrl;
  late final TextEditingController _otaIpCtrl;
  late final TextEditingController _otaPortCtrl;
  final FirmwareUpdateService _fw = FirmwareUpdateService();

  FirmwareManifest? _manifest;
  String _cacheDir = '';
  String _status = '';
  bool _busy = false;
  String? _selectedCom;
  /// Nepollujeme nativní enumeraci COM při každém rebuildu — stabilnější (Windows driver / libserialport).
  List<String> _serialPortsCache = const [];
  String? _serialPortsError;

  @override
  void initState() {
    super.initState();
    _manifestUrlCtrl = TextEditingController(
      text: effectiveFirmwareManifestUrl(widget.draft.globalSettings.firmwareManifestUrl),
    );
    final wifi = widget.draft.globalSettings.devices.where((d) => d.type == 'wifi' && d.ipAddress.trim().isNotEmpty);
    final first = wifi.isEmpty ? null : wifi.first;
    _otaIpCtrl = TextEditingController(text: first?.ipAddress ?? '');
    _otaPortCtrl = TextEditingController(text: '${first?.udpPort ?? 4210}');
    unawaited(_initCache());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSerialPorts();
    });
  }

  Future<void> _initCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      if (mounted) {
        setState(() => _cacheDir = p.join(dir.path, 'firmware_cache'));
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'Nelze založit cache (path_provider).');
    }
  }

  @override
  void dispose() {
    _manifestUrlCtrl.dispose();
    _otaIpCtrl.dispose();
    _otaPortCtrl.dispose();
    _fw.close();
    super.dispose();
  }

  String _normalizeManifestUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!u.contains('manifest.json')) {
      if (!u.endsWith('/')) u = '$u/';
      u = '${u}manifest.json';
    }
    return u;
  }

  Future<void> _saveManifestUrl() async {
    final resolved = effectiveFirmwareManifestUrl(_manifestUrlCtrl.text);
    if (_manifestUrlCtrl.text != resolved) {
      _manifestUrlCtrl.text = resolved;
      _manifestUrlCtrl.selection = TextSelection.collapsed(offset: resolved.length);
    }
    widget.onGlobalChanged(widget.draft.globalSettings.copyWith(firmwareManifestUrl: resolved));
  }

  Future<void> _fetchManifest() async {
    await _saveManifestUrl();
    final url = _normalizeManifestUrl(_manifestUrlCtrl.text);
    if (url.isEmpty) {
      setState(() => _status = 'Zadej URL manifestu (např. …/firmware/latest/).');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Načítám manifest…';
      _manifest = null;
    });
    try {
      final m = await _fw.fetchManifest(url);
      if (!mounted) return;
      setState(() {
        _manifest = m;
        _status = 'Manifest OK — verze ${m.version}, čip ${m.chip}, ${m.parts.length} souborů.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Chyba manifestu: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadBins() async {
    final m = _manifest;
    if (m == null || _cacheDir.isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Stahuji…';
    });
    try {
      final root = await _fw.downloadAll(
        manifest: m,
        cacheDir: _cacheDir,
        onProgress: (msg) {
          if (mounted) setState(() => _status = msg);
        },
      );
      if (!mounted) return;
      setState(() => _status = 'Staženo do: $root');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Stažení selhalo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flashUsb() async {
    final m = _manifest;
    if (m == null || _cacheDir.isEmpty) return;
    final com = _selectedCom?.trim();
    if (com == null || com.isEmpty) {
      setState(() => _status = 'Vyber COM / sériový port.');
      return;
    }
    final root = p.join(_cacheDir, m.version);
    if (!Directory(root).existsSync()) {
      setState(() => _status = 'Nejdřív stáhni binárky (tlačítko výše).');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Flashuji přes esptool… (vypni v aplikaci stream na stejný COM)';
    });
    try {
      final (ok, log) = await EsptoolFlashRunner.flashSerial(
        manifest: m,
        downloadedDir: root,
        comPort: com,
      );
      if (!mounted) return;
      setState(() => _status = ok ? 'Flash OK.\n$log' : 'Flash selhal.\n$log');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Výjimka: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _probeEspReachability() async {
    final ip = _otaIpCtrl.text.trim();
    final port = int.tryParse(_otaPortCtrl.text.trim()) ?? 4210;
    if (ip.isEmpty) {
      setState(() => _status = 'Zadej IP zařízení pro ověření (UDP PONG).');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Ověřuji zařízení (UDP, max 2 s)…';
    });
    final pong = await LedDiscoveryService.queryPong(ip, udpPort: port);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (pong == null) {
        _status =
            'Zařízení neodpovědělo v čase — offline, špatná IP/port/firewall, nebo firmware bez DISCOVER odpovědi.';
      } else {
        _status =
            'Online: ${pong.name} · LED ${pong.ledCount} · verze ${pong.version} (ESP32_PONG).';
      }
    });
  }

  Future<void> _otaWifi() async {
    final m = _manifest;
    final u = m?.resolvedOtaHttpUrl?.trim();
    if (u == null || u.isEmpty) {
      setState(() => _status = 'Manifest nemá použitelnou OTA URL (ota_http_url ani odvozený parts[].url).');
      return;
    }
    final ip = _otaIpCtrl.text.trim();
    final port = int.tryParse(_otaPortCtrl.text.trim()) ?? 4210;
    if (ip.isEmpty) {
      setState(() => _status = 'Zadej IP ESP (Wi‑Fi).');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Odesílám OTA_HTTP na $ip:$port…';
    });
    final ok = await UdpDeviceCommands.sendOtaHttpUrl(ip, port, u);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = ok
          ? 'Příkaz odeslán. ESP stáhne firmware a restartuje se (kontroluj log / LED).'
          : 'UDP se nepodařilo odeslat.';
    });
  }

  void _refreshSerialPorts() {
    if (!mounted) return;
    try {
      final raw = SerialPort.availablePorts;
      final seen = <String>{};
      final unique = <String>[];
      for (final name in raw) {
        if (seen.add(name)) unique.add(name);
      }
      if (!mounted) return;
      setState(() {
        _serialPortsError = null;
        _serialPortsCache = unique;
        if (_selectedCom != null && !unique.contains(_selectedCom)) {
          _selectedCom = null;
        }
      });
    } catch (e, st) {
      assert(() {
        debugPrint('FirmwareSettingsTab: SerialPort.availablePorts: $e\n$st');
        return true;
      }());
      if (!mounted) return;
      setState(() {
        _serialPortsError = '$e';
        _serialPortsCache = const [];
        _selectedCom = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final innerMax = AppBreakpoints.settingsContentInnerMax(widget.maxWidth);
    final scheme = Theme.of(context).colorScheme;
    final ports = _serialPortsCache;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Firmware ESP', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'CI build z repa může publikovat manifest na GitHub Pages. Zde načteš manifest, stáhneš .bin '
                'a flashneš přes USB (vyžaduje esptool v PATH) nebo spustíš OTA přes Wi‑Fi (UDP příkaz z firmware). '
                'Přechod na tabulku s dvěma OTA oddíly vyžaduje jednou úplný flash přes USB.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _manifestUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL manifestu (GitHub Pages)',
                  hintText: 'https://alfredkrutina.github.io/ambilight/firmware/latest/',
                  border: OutlineInputBorder(),
                  helperText: 'Výchozí z globálního nastavení; bez souboru doplníme /manifest.json',
                ),
                onChanged: (_) => unawaited(_saveManifestUrl()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _fetchManifest,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Načíst manifest'),
                  ),
                  FilledButton.icon(
                    onPressed: (_busy || _manifest == null) ? null : _downloadBins,
                    icon: const Icon(Icons.download_done_outlined),
                    label: const Text('Stáhnout binárky'),
                  ),
                ],
              ),
              if (_manifest != null) ...[
                const SizedBox(height: 12),
                Text('Verze: ${_manifest!.version} · čip: ${_manifest!.chip}', style: Theme.of(context).textTheme.bodyMedium),
                for (final part in _manifest!.parts)
                  Text('• ${part.file} @ ${part.offset}', style: Theme.of(context).textTheme.bodySmall),
                if ((_manifest!.resolvedOtaHttpUrl ?? '').isNotEmpty)
                  Text('OTA URL: ${_manifest!.resolvedOtaHttpUrl}', style: Theme.of(context).textTheme.bodySmall),
              ],
              const Divider(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text('Flash přes USB (COM)', style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Obnovit seznam portů',
                    onPressed: _busy ? null : _refreshSerialPorts,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_serialPortsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Sériové porty nelze načíst: $_serialPortsError',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
              if (ports.isEmpty)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sériový port',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _serialPortsError != null ? 'Zkuste „Obnovit“ nebo oprávnění / ovladač.' : 'Žádný COM — připoj ESP USB',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedCom != null && ports.contains(_selectedCom!) ? _selectedCom : null,
                  decoration: const InputDecoration(
                    labelText: 'Sériový port',
                    border: OutlineInputBorder(),
                  ),
                  items: [for (final port in ports) DropdownMenuItem(value: port, child: Text(port))],
                  onChanged: _busy ? null : (v) => setState(() => _selectedCom = v),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_busy || _manifest == null) ? null : _flashUsb,
                icon: const Icon(Icons.usb_rounded),
                label: const Text('Flashovat přes esptool'),
              ),
              const Divider(height: 32),
              Text('OTA přes Wi‑Fi (UDP)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _otaIpCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP zařízení',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _otaPortCtrl,
                decoration: const InputDecoration(
                  labelText: 'UDP port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Text(
                _manifest == null
                    ? 'Nejdřív výše načti manifest — bez něj není známá HTTPS URL pro OTA_HTTP.'
                    : ((_manifest!.resolvedOtaHttpUrl ?? '').isEmpty)
                        ? 'V manifestu chybí OTA URL — dopiš root pole ota_http_url nebo parts s URL na aplikační .bin.'
                        : 'Pro OTA se použije: ${_manifest!.resolvedOtaHttpUrl}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _probeEspReachability,
                    icon: const Icon(Icons.router_outlined),
                    label: const Text('Ověřit dosah (UDP PONG)'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: (_busy ||
                            _manifest == null ||
                            (_manifest!.resolvedOtaHttpUrl ?? '').isEmpty)
                        ? null
                        : _otaWifi,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Odeslat OTA_HTTP'),
                  ),
                ],
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(_status, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
