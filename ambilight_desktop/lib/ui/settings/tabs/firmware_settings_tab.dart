import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/config_models.dart';
import '../../../data/udp_device_commands.dart';
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

  @override
  void initState() {
    super.initState();
    _manifestUrlCtrl = TextEditingController(text: widget.draft.globalSettings.firmwareManifestUrl);
    final wifi = widget.draft.globalSettings.devices.where((d) => d.type == 'wifi' && d.ipAddress.trim().isNotEmpty);
    final first = wifi.isEmpty ? null : wifi.first;
    _otaIpCtrl = TextEditingController(text: first?.ipAddress ?? '');
    _otaPortCtrl = TextEditingController(text: '${first?.udpPort ?? 4210}');
    unawaited(_initCache());
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
    widget.onGlobalChanged(widget.draft.globalSettings.copyWith(firmwareManifestUrl: _manifestUrlCtrl.text.trim()));
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

  Future<void> _otaWifi() async {
    final m = _manifest;
    final u = m?.otaHttpUrl?.trim();
    if (u == null || u.isEmpty) {
      setState(() => _status = 'Manifest nemá ota_http_url.');
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

  List<String> _serialPorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      return <String>['(chyba portů: $e)'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final innerMax = AppBreakpoints.maxContentWidth(widget.maxWidth).clamp(280.0, widget.maxWidth);
    final scheme = Theme.of(context).colorScheme;
    final ports = _serialPorts().where((e) => !e.startsWith('(chyba')).toList();

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
                  hintText: 'https://<owner>.github.io/<repo>/firmware/latest/',
                  border: OutlineInputBorder(),
                  helperText: 'Bez názvu souboru doplníme /manifest.json',
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
                if ((_manifest!.otaHttpUrl ?? '').isNotEmpty)
                  Text('OTA URL: ${_manifest!.otaHttpUrl}', style: Theme.of(context).textTheme.bodySmall),
              ],
              const Divider(height: 32),
              Text('Flash přes USB (COM)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCom != null && ports.contains(_selectedCom!) ? _selectedCom : null,
                decoration: const InputDecoration(
                  labelText: 'Sériový port',
                  border: OutlineInputBorder(),
                ),
                items: ports.isEmpty
                    ? const [DropdownMenuItem(value: '__none__', enabled: false, child: Text('Žádný COM'))]
                    : [for (final port in ports) DropdownMenuItem(value: port, child: Text(port))],
                onChanged: (_busy || ports.isEmpty)
                    ? null
                    : (v) => setState(() => _selectedCom = v == '__none__' ? null : v),
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
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: (_busy || _manifest == null) ? null : _otaWifi,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Odeslat OTA_HTTP'),
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
