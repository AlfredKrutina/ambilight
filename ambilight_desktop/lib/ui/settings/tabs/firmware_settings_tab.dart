import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/config_models.dart';
import '../../../data/udp_device_commands.dart';
import '../../../l10n/context_ext.dart';
import '../../../services/led_discovery_service.dart';
import '../../../features/firmware_legacy_old_code/esptool_flash_runner.dart';
import '../../../features/firmware_legacy_old_code/firmware_manifest.dart';
import '../../../features/firmware_legacy_old_code/firmware_update_service.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/firmware_progress_dialog.dart';

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
  List<String> _serialPortsCache = const [];
  String? _serialPortsError;
  /// Poslední známý stav `DEBUG_REJ88` na lampě (`null` = ještě nečteno / neznámé).
  bool? _dbgRej88Last;

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
      if (mounted) {
        setState(() => _status = context.l10n.fwStatusCacheFail);
      }
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

  String _l10nOtaReject(OtaHttpCommandRejectReason r) {
    final l = context.l10n;
    return switch (r) {
      OtaHttpCommandRejectReason.invalidTargetIp => l.fwStatusOtaInvalidTarget,
      OtaHttpCommandRejectReason.urlTooShort => l.fwStatusOtaUrlTooShort,
      OtaHttpCommandRejectReason.urlTooLong => l.fwStatusOtaUrlTooLong,
      OtaHttpCommandRejectReason.urlSchemeNotHttp => l.fwStatusOtaBadScheme,
      OtaHttpCommandRejectReason.invalidUrlCharacters => l.fwStatusOtaInvalidChars,
      OtaHttpCommandRejectReason.commandPayloadInvalid => l.fwStatusOtaPayloadInvalid,
    };
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
    final l10n = context.l10n;
    await _saveManifestUrl();
    final url = _normalizeManifestUrl(_manifestUrlCtrl.text);
    if (url.isEmpty) {
      setState(() => _status = l10n.fwStatusEnterManifestUrl);
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.fwStatusLoadingManifest;
      _manifest = null;
    });
    try {
      final m = await _fw.fetchManifest(url);
      if (!mounted) return;
      setState(() {
        _manifest = m;
        _status = l10n.fwStatusManifestOk(m.version, m.chip, m.parts.length);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = l10n.fwStatusManifestError('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadBins() async {
    final l10n = context.l10n;
    final m = _manifest;
    if (m == null || _cacheDir.isEmpty) return;
    setState(() {
      _busy = true;
      _status = l10n.fwStatusDownloading;
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
      setState(() => _status = l10n.fwStatusDownloadedTo(root));
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = l10n.fwStatusDownloadFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flashUsb() async {
    final l10n = context.l10n;
    final m = _manifest;
    if (m == null || _cacheDir.isEmpty) return;
    final com = _selectedCom?.trim();
    if (com == null || com.isEmpty) {
      setState(() => _status = l10n.fwStatusPickCom);
      return;
    }
    final root = p.join(_cacheDir, m.version);
    if (!Directory(root).existsSync()) {
      setState(() => _status = l10n.fwStatusDownloadBinsFirst);
      return;
    }
    setState(() => _busy = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => FirmwareProgressDialog(
          title: l10n.fwProgressUsbTitle,
          initialSubtitle: l10n.fwProgressUsbSubtitle,
          onRun: (h) async {
            try {
              final (ok, log) = await EsptoolFlashRunner.flashSerial(
                manifest: m,
                downloadedDir: root,
                comPort: com,
                shouldCancel: () => h.isCancelled,
              );
              if (!context.mounted) return false;
              if (h.isCancelled) {
                setState(() => _status = l10n.fwProgressFlashCancelled);
                return false;
              }
              setState(() => _status = ok ? l10n.fwStatusFlashOk(log) : l10n.fwStatusFlashFail(log));
              return false;
            } catch (e) {
              if (context.mounted) {
                setState(() => _status = l10n.fwStatusException('$e'));
              }
              return false;
            }
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _probeEspReachability() async {
    final l10n = context.l10n;
    final ip = _otaIpCtrl.text.trim();
    final port = int.tryParse(_otaPortCtrl.text.trim()) ?? 4210;
    if (ip.isEmpty) {
      setState(() => _status = l10n.fwStatusEnterIpProbe);
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.fwStatusProbing;
    });
    final pong = await LedDiscoveryService.queryPong(ip, udpPort: port);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (pong == null) {
        _status = l10n.fwStatusProbeTimeout;
      } else {
        var line = l10n.fwStatusProbeOnline(pong.name, pong.ledCount, pong.version);
        if (pong.fwDebugRejectSubnet19216888 == true) {
          line = '$line${l10n.fwStatusProbeRejectOn}';
        } else if (pong.fwDebugRejectSubnet19216888 == false) {
          line = '$line${l10n.fwStatusProbeRejectOff}';
        }
        _status = line;
      }
    });
  }

  String _dbgRej88StateWord() {
    final l = context.l10n;
    final v = _dbgRej88Last;
    if (v == null) return l.fwDebugReject88Unknown;
    return v ? l.fwDebugReject88On : l.fwDebugReject88Off;
  }

  Future<void> _queryDebugReject88() async {
    final l10n = context.l10n;
    final ip = _otaIpCtrl.text.trim();
    final port = int.tryParse(_otaPortCtrl.text.trim()) ?? 4210;
    if (ip.isEmpty) {
      setState(() => _status = l10n.fwStatusEnterIpProbe);
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.fwStatusProbing;
    });
    final v = await UdpDeviceCommands.queryDebugRejectSubnet88(ip, port);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (v == null) {
        _status = l10n.fwDebugReject88SetFail;
      } else {
        _dbgRej88Last = v;
        _status = l10n.fwDebugReject88Current(_dbgRej88StateWord());
      }
    });
  }

  Future<void> _setDebugReject88(bool on) async {
    final l10n = context.l10n;
    final ip = _otaIpCtrl.text.trim();
    final port = int.tryParse(_otaPortCtrl.text.trim()) ?? 4210;
    if (ip.isEmpty) {
      setState(() => _status = l10n.fwStatusEnterIpProbe);
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.fwStatusProbing;
    });
    final ok = await UdpDeviceCommands.setDebugRejectSubnet88(ip, port, on);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _dbgRej88Last = on;
        _status = l10n.fwDebugReject88SetOk;
      } else {
        _status = l10n.fwDebugReject88SetFail;
      }
    });
  }

  void _fillOtaFromFirstWifiDevice() {
    final l10n = context.l10n;
    final wifi = widget.draft.globalSettings.devices.where((d) => d.type == 'wifi' && d.ipAddress.trim().isNotEmpty);
    final first = wifi.isEmpty ? null : wifi.first;
    if (first == null) {
      setState(() => _status = l10n.fwStatusNoWifiDevice);
      return;
    }
    setState(() {
      _otaIpCtrl.text = first.ipAddress.trim();
      _otaPortCtrl.text = '${first.udpPort}';
      _status = l10n.fwStatusFilledFromDevice(first.name, first.ipAddress.trim(), '${first.udpPort}');
    });
  }

  Future<void> _otaWifi() async {
    final l10n = context.l10n;
    final m = _manifest;
    final u = m?.resolvedOtaHttpUrl?.trim();
    if (u == null || u.isEmpty) {
      setState(() => _status = l10n.fwStatusNoOtaUrl);
      return;
    }
    final ip = _otaIpCtrl.text.trim();
    final port = int.tryParse(_otaPortCtrl.text.trim()) ?? 4210;
    if (ip.isEmpty) {
      setState(() => _status = l10n.fwStatusEnterIpEsp);
      return;
    }
    final pre = UdpDeviceCommands.rejectReasonForOtaHttpCommand(ip, port, u);
    if (pre != null) {
      setState(() => _status = _l10nOtaReject(pre));
      return;
    }
    setState(() => _busy = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => FirmwareProgressDialog(
          title: l10n.fwProgressOtaTitle,
          initialSubtitle: l10n.fwProgressOtaSending,
          onRun: (h) async {
            try {
              final (sent, version) = await UdpDeviceCommands.sendOtaHttpUrlAwaitOtaOk(
                ip,
                port,
                u,
                shouldCancel: () => h.isCancelled,
                onCommandSent: () {
                  if (context.mounted) {
                    h.updateSubtitle(l10n.fwProgressOtaAwaitNotify);
                  }
                },
                logContext: 'OTA_HTTP',
              );
              if (!context.mounted) return false;
              if (h.isCancelled) return false;
              if (!sent) {
                setState(() => _status = l10n.fwStatusUdpFailed);
                return false;
              }
              final msg = version != null ? l10n.fwProgressOtaSuccessNotify(version) : l10n.fwStatusOtaSent;
              setState(() => _status = msg);
              h.updateSubtitle(
                version != null ? l10n.fwProgressOtaSuccessNotify(version) : l10n.fwProgressOtaDevicePhase,
              );
              h.showCloseOnly();
              return true;
            } catch (e) {
              if (context.mounted) {
                setState(() => _status = l10n.fwStatusException('$e'));
              }
              return false;
            }
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  Widget _card(BuildContext context, {required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerTheme: const DividerThemeData(space: 1)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final innerMax = AppBreakpoints.settingsContentInnerMax(widget.maxWidth);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final ports = _serialPortsCache;
    final m = _manifest;
    final otaUrl = m?.resolvedOtaHttpUrl?.trim() ?? '';
    final otaReady = m != null && otaUrl.isNotEmpty;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.fwTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                l10n.fwIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _card(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.integration_instructions_outlined, size: 22, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.fwManifestLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _manifestUrlCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.fwManifestUrlLabel,
                        hintText: l10n.fwManifestUrlHint,
                        border: const OutlineInputBorder(),
                        helperText: l10n.fwManifestHelper,
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
                          label: Text(l10n.fwLoadManifest),
                        ),
                        FilledButton.icon(
                          onPressed: (_busy || m == null) ? null : _downloadBins,
                          icon: const Icon(Icons.download_done_outlined),
                          label: Text(l10n.fwDownloadBins),
                        ),
                      ],
                    ),
                    if (m != null) ...[
                      const SizedBox(height: 16),
                      Divider(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                      const SizedBox(height: 12),
                      Text(l10n.fwVersionChipLine(m.version, m.chip), style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      for (final part in m.parts)
                        Text(
                          l10n.fwPartBullet(part.file, part.offset),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      if (otaUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          l10n.fwOtaUrlLine(otaUrl),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              _card(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.usb_rounded, size: 22, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.fwFlashUsbTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.fwRefreshPortsTooltip,
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
                          l10n.fwSerialPortsError(_serialPortsError!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
                        ),
                      ),
                    if (ports.isEmpty)
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.fwSerialPortLabel,
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          _serialPortsError != null ? l10n.fwNoComHintDriver : l10n.fwNoComEmpty,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedCom != null && ports.contains(_selectedCom!) ? _selectedCom : null,
                        decoration: InputDecoration(
                          labelText: l10n.fwSerialPortLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: [for (final port in ports) DropdownMenuItem(value: port, child: Text(port))],
                        onChanged: _busy ? null : (v) => setState(() => _selectedCom = v),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: (_busy || m == null) ? null : _flashUsb,
                      icon: const Icon(Icons.memory_rounded),
                      label: Text(l10n.fwFlashEsptool),
                    ),
                  ],
                ),
              ),
              _card(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.wifi_tethering, size: 22, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.fwOtaUdpTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Tooltip(
                          message: l10n.fwFillFromDevicesTooltip,
                          child: TextButton.icon(
                            onPressed: _busy ? null : _fillOtaFromFirstWifiDevice,
                            icon: const Icon(Icons.devices_other, size: 18),
                            label: Text(l10n.fwFillFromDevices),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otaIpCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.fwDeviceIpLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _otaPortCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.firmwareUdpPort,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      m == null
                          ? l10n.fwOtaHintNeedManifest
                          : otaUrl.isEmpty
                              ? l10n.fwOtaHintMissingUrl
                              : l10n.fwOtaHintWillUse(otaUrl),
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
                          label: Text(l10n.fwVerifyUdpPong),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: (_busy || !otaReady) ? null : _otaWifi,
                          icon: const Icon(Icons.system_update_alt),
                          label: Text(l10n.fwSendOtaHttp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _card(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bug_report_outlined, size: 22, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.fwDebugToolsTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.fwDebugReject88Body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.fwDebugReject88Current(_dbgRej88StateWord()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _queryDebugReject88,
                          icon: const Icon(Icons.help_outline),
                          label: Text(l10n.fwDebugReject88Query),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => unawaited(_setDebugReject88(true)),
                          icon: const Icon(Icons.block_flipped),
                          label: Text(l10n.fwDebugReject88Enable),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => unawaited(_setDebugReject88(false)),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(l10n.fwDebugReject88Disable),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_status.isNotEmpty)
                Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: SelectableText(
                      _status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
