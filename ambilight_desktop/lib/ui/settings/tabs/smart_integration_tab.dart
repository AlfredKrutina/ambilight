import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/config_models.dart';
import '../../../core/models/smart_lights_models.dart';
import '../../../features/smart_lights/ha_api_client.dart';
import '../../../features/smart_lights/homekit_bridge.dart';
import '../../../l10n/context_ext.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';
import '../widgets/virtual_room_editor.dart';

/// Home Assistant (REST), Apple HomeKit (macOS), návod na Google Home přes HA.
class SmartIntegrationTab extends StatefulWidget {
  const SmartIntegrationTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onSmartLightsChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<SmartLightsSettings> onSmartLightsChanged;

  @override
  State<SmartIntegrationTab> createState() => _SmartIntegrationTabState();
}

class _SmartIntegrationTabState extends State<SmartIntegrationTab> {
  String _haStatus = '';
  String _hkStatus = '';
  List<Map<String, String>> _hkLights = const [];

  SmartLightsSettings get _sl => widget.draft.smartLights;

  Future<void> _openUrl(String url) async {
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _testHa() async {
    final sl = _sl;
    final l10n = context.l10n;
    if (sl.haBaseUrl.trim().isEmpty || sl.haLongLivedToken.trim().isEmpty) {
      setState(() => _haStatus = l10n.smartHaFillUrlToken);
      return;
    }
    setState(() => _haStatus = l10n.smartHaStatusTesting);
    final c = HaApiClient(
      baseUrl: sl.haBaseUrl,
      token: sl.haLongLivedToken,
      allowInsecureCert: sl.haAllowInsecureCert,
      timeout: Duration(seconds: sl.haTimeoutSeconds.clamp(3, 120)),
    );
    final (ok, msg) = await c.ping();
    c.close();
    if (!mounted) return;
    setState(() => _haStatus = ok ? l10n.smartHaStatusOk(msg) : l10n.smartHaStatusErr(msg));
  }

  Future<void> _refreshHomeKit() async {
    if (!Platform.isMacOS) return;
    setState(() => _hkStatus = context.l10n.smartHomeKitLoading);
    final list = await HomeKitBridge.listLights();
    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _hkLights = list;
      _hkStatus = list.isEmpty ? l10n.smartHomeKitEmpty : l10n.smartHomeKitCount(list.length);
    });
  }

  void _patch(SmartLightsSettings next) => widget.onSmartLightsChanged(next);

  @override
  Widget build(BuildContext context) {
    final sl = _sl;
    final innerMax = AppBreakpoints.maxContentWidth(widget.maxWidth).clamp(280.0, widget.maxWidth);
    final scheme = Theme.of(context).colorScheme;

    Future<void> pickHaLight() async {
      final loc = context.l10n;
      if (sl.haBaseUrl.trim().isEmpty || sl.haLongLivedToken.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.smartHaFillUrlToken)),
        );
        return;
      }
      final client = HaApiClient(
        baseUrl: sl.haBaseUrl,
        token: sl.haLongLivedToken,
        allowInsecureCert: sl.haAllowInsecureCert,
        timeout: Duration(seconds: sl.haTimeoutSeconds.clamp(3, 120)),
      );
      final (ok, states, err) = await client.getStates();
      client.close();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.smartHaError(err))));
        return;
      }
      final lights = states.where((e) => (e['entity_id'] as String?)?.startsWith('light.') ?? false).toList();
      if (lights.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.smartHaNoLights)),
        );
        return;
      }
      final picked = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final dl = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Text(dl.smartHaPickLightTitle),
            content: SizedBox(
              width: 420,
              height: 360,
              child: ListView.builder(
                itemCount: lights.length,
                itemBuilder: (_, i) {
                  final e = lights[i];
                  final id = e['entity_id'] as String? ?? '';
                  final attrs = e['attributes'];
                  final name = attrs is Map && attrs['friendly_name'] != null
                      ? attrs['friendly_name'].toString()
                      : id;
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(id, style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(ctx, id),
                  );
                },
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(dl.cancel))],
          );
        },
      );
      if (picked == null || !mounted) return;
      final id = 'fx_${DateTime.now().millisecondsSinceEpoch}';
      final n = sl.fixtures.length;
      final ang = n * (math.pi * 2 / 8);
      final rx = (0.5 + 0.34 * math.cos(ang)).clamp(0.08, 0.92);
      final ry = (0.42 + 0.26 * math.sin(ang)).clamp(0.12, 0.88);
      final nextFx = SmartFixture(
        id: id,
        displayName: picked,
        backend: SmartLightBackend.homeAssistant,
        haEntityId: picked,
        binding: const SmartLightBinding(kind: SmartBindingKind.globalMean),
        roomX: rx,
        roomY: ry,
      );
      _patch(sl.copyWith(fixtures: [...sl.fixtures, nextFx]));
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.smartHomeTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                context.l10n.smartHomeIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(context.l10n.smartPushColorsTile)),
                    AmbiHelpIcon(message: context.l10n.smartPushColorsHelpTooltip),
                  ],
                ),
                subtitle: Text(context.l10n.smartPushColorsSubtitle),
                value: sl.enabled,
                onChanged: (v) => _patch(sl.copyWith(enabled: v)),
              ),
              const Divider(height: 32),
              Text(context.l10n.smartHaSection, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: sl.haBaseUrl,
                decoration: InputDecoration(
                  labelText: context.l10n.smartHaUrlLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => _patch(sl.copyWith(haBaseUrl: v.trim())),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('ha_tok_${sl.haLongLivedToken.isNotEmpty}'),
                initialValue: sl.haLongLivedToken,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.smartHaTokenLabel,
                  helperText: context.l10n.smartHaTokenHelper,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => _patch(sl.copyWith(haLongLivedToken: v)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(context.l10n.smartHaTrustCertTile),
                subtitle: Text(context.l10n.smartHaTrustCertSubtitle),
                value: sl.haAllowInsecureCert,
                onChanged: (v) => _patch(sl.copyWith(haAllowInsecureCert: v)),
              ),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _testHa,
                    icon: const Icon(Icons.wifi_protected_setup),
                    label: Text(context.l10n.smartTestConnection),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: pickHaLight,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.smartAddHaLight),
                  ),
                ],
              ),
              if (_haStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_haStatus, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: sl.maxUpdateHzPerFixture.toString(),
                      decoration: InputDecoration(
                        labelText: context.l10n.smartMaxHzLabel,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n != null) _patch(sl.copyWith(maxUpdateHzPerFixture: n.clamp(1, 30)));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: sl.globalBrightnessCapPct.toString(),
                      decoration: InputDecoration(
                        labelText: context.l10n.smartBrightnessCapLabel,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n != null) _patch(sl.copyWith(globalBrightnessCapPct: n.clamp(1, 100)));
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(context.l10n.smartHomeKitSection, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (!Platform.isMacOS)
                Text(
                  context.l10n.smartHomeKitNonMac,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else ...[
                Text(_hkStatus, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _refreshHomeKit,
                  icon: const Icon(Icons.home_outlined),
                  label: Text(context.l10n.smartRefreshHomeKit),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hkLights.map((L) {
                    final uuid = L['uuid'] ?? '';
                    final name = L['name'] ?? uuid;
                    return ActionChip(
                      label: Text(name, overflow: TextOverflow.ellipsis),
                      onPressed: () {
                        final id = 'fx_${DateTime.now().millisecondsSinceEpoch}';
                        final n = sl.fixtures.length;
                        final ang = n * (math.pi * 2 / 8);
                        final rx = (0.5 + 0.34 * math.cos(ang)).clamp(0.08, 0.92);
                        final ry = (0.42 + 0.26 * math.sin(ang)).clamp(0.12, 0.88);
                        final fx = SmartFixture(
                          id: id,
                          displayName: name,
                          backend: SmartLightBackend.appleHomeKit,
                          homeKitAccessoryUuid: uuid,
                          binding: const SmartLightBinding(kind: SmartBindingKind.globalMean),
                          roomX: rx,
                          roomY: ry,
                        );
                        _patch(sl.copyWith(fixtures: [...sl.fixtures, fx]));
                      },
                    );
                  }).toList(),
                ),
              ],
              const Divider(height: 32),
              Text(context.l10n.smartGoogleSection, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                context.l10n.smartGoogleBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(
                      'https://www.home-assistant.io/integrations/google_assistant/',
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(context.l10n.smartGoogleDocButton),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl('https://my.home-assistant.io/'),
                    icon: const Icon(Icons.link),
                    label: Text(context.l10n.smartMyHaButton),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(context.l10n.smartVirtualRoomSection, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                context.l10n.smartVirtualRoomIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              VirtualRoomEditor(sl: sl, onChanged: _patch),
              const Divider(height: 32),
              Text(context.l10n.smartFixturesTitle(sl.fixtures.length), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (sl.fixtures.isEmpty)
                Text(context.l10n.smartFixturesEmpty, style: Theme.of(context).textTheme.bodySmall),
              if (sl.fixtures.isNotEmpty)
                for (final f in sl.fixtures)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(f.displayName, style: Theme.of(context).textTheme.titleSmall),
                              ),
                              IconButton(
                                tooltip: context.l10n.smartFixtureRemoveTooltip,
                                onPressed: () {
                                  _patch(sl.copyWith(
                                    fixtures: sl.fixtures.where((x) => x.id != f.id).toList(),
                                  ));
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          Text(
                            f.backend == SmartLightBackend.homeAssistant
                                ? context.l10n.smartFixtureHaLine(f.haEntityId)
                                : context.l10n.smartFixtureHkLine(f.homeKitAccessoryUuid),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          DropdownButtonFormField<SmartBindingKind>(
                            value: f.binding.kind,
                            decoration: InputDecoration(labelText: context.l10n.smartBindingLabel),
                            items: [
                              DropdownMenuItem(
                                value: SmartBindingKind.globalMean,
                                child: Text(context.l10n.smartBindingGlobalMean),
                              ),
                              DropdownMenuItem(
                                value: SmartBindingKind.virtualLedRange,
                                child: Text(context.l10n.smartBindingLedRange),
                              ),
                              DropdownMenuItem(
                                value: SmartBindingKind.screenEdge,
                                child: Text(context.l10n.smartBindingScreenEdge),
                              ),
                            ],
                            onChanged: (k) {
                              if (k == null) return;
                              _patch(sl.copyWith(
                                fixtures: sl.fixtures
                                    .map((x) => x.id == f.id ? x.copyWith(binding: x.binding.copyWith(kind: k)) : x)
                                    .toList(),
                              ));
                            },
                          ),
                          if (f.binding.kind == SmartBindingKind.virtualLedRange) ...[
                            TextFormField(
                              initialValue: f.binding.deviceId ?? '',
                              decoration: InputDecoration(
                                labelText: context.l10n.smartDeviceIdOptional,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) => _patch(sl.copyWith(
                                fixtures: sl.fixtures
                                    .map(
                                      (x) => x.id == f.id
                                          ? x.copyWith(
                                              binding: x.binding.copyWith(
                                                deviceId: v.trim().isEmpty ? null : v.trim(),
                                              ),
                                            )
                                          : x,
                                    )
                                    .toList(),
                              )),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: f.binding.ledStart.toString(),
                                    decoration: InputDecoration(
                                      labelText: context.l10n.smartBindingLedStartField,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (v) {
                                      final n = int.tryParse(v.trim());
                                      if (n == null) return;
                                      _patch(sl.copyWith(
                                        fixtures: sl.fixtures
                                            .map(
                                              (x) => x.id == f.id
                                                  ? x.copyWith(binding: x.binding.copyWith(ledStart: n))
                                                  : x,
                                            )
                                            .toList(),
                                      ));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: f.binding.ledEnd.toString(),
                                    decoration: InputDecoration(
                                      labelText: context.l10n.smartBindingLedEndField,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (v) {
                                      final n = int.tryParse(v.trim());
                                      if (n == null) return;
                                      _patch(sl.copyWith(
                                        fixtures: sl.fixtures
                                            .map(
                                              (x) => x.id == f.id
                                                  ? x.copyWith(binding: x.binding.copyWith(ledEnd: n))
                                                  : x,
                                            )
                                            .toList(),
                                      ));
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (f.binding.kind == SmartBindingKind.screenEdge) ...[
                            DropdownButtonFormField<String>(
                              value: f.binding.edge,
                              decoration: InputDecoration(labelText: context.l10n.smartEdgeLabel),
                              items: [
                                DropdownMenuItem(value: 'left', child: Text(context.l10n.zoneEdgeLeft)),
                                DropdownMenuItem(value: 'right', child: Text(context.l10n.zoneEdgeRight)),
                                DropdownMenuItem(value: 'top', child: Text(context.l10n.zoneEdgeTop)),
                                DropdownMenuItem(value: 'bottom', child: Text(context.l10n.zoneEdgeBottom)),
                              ],
                              onChanged: (e) {
                                if (e == null) return;
                                _patch(sl.copyWith(
                                  fixtures: sl.fixtures
                                      .map((x) => x.id == f.id ? x.copyWith(binding: x.binding.copyWith(edge: e)) : x)
                                      .toList(),
                                ));
                              },
                            ),
                            TextFormField(
                              initialValue: f.binding.monitorIndex.toString(),
                              decoration: InputDecoration(
                                labelText: context.l10n.smartMonitorIndexBinding,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v.trim());
                                if (n == null) return;
                                _patch(sl.copyWith(
                                  fixtures: sl.fixtures
                                      .map(
                                        (x) => x.id == f.id
                                            ? x.copyWith(binding: x.binding.copyWith(monitorIndex: n))
                                            : x,
                                      )
                                      .toList(),
                                ));
                              },
                            ),
                          ],
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.l10n.pcHealthTileEnabled),
                            value: f.enabled,
                            onChanged: (v) => _patch(sl.copyWith(
                              fixtures: sl.fixtures.map((x) => x.id == f.id ? x.copyWith(enabled: v) : x).toList(),
                            )),
                          ),
                        ],
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
