import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/config_models.dart';
import '../../../core/models/smart_lights_models.dart';
import '../../../features/smart_lights/ha_api_client.dart';
import '../../../features/smart_lights/homekit_bridge.dart';
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
    if (sl.haBaseUrl.trim().isEmpty || sl.haLongLivedToken.trim().isEmpty) {
      setState(() => _haStatus = 'Vyplň URL a token.');
      return;
    }
    setState(() => _haStatus = 'Testuji…');
    final c = HaApiClient(
      baseUrl: sl.haBaseUrl,
      token: sl.haLongLivedToken,
      allowInsecureCert: sl.haAllowInsecureCert,
      timeout: Duration(seconds: sl.haTimeoutSeconds.clamp(3, 120)),
    );
    final (ok, msg) = await c.ping();
    c.close();
    if (!mounted) return;
    setState(() => _haStatus = ok ? 'OK: $msg' : 'Chyba: $msg');
  }

  Future<void> _refreshHomeKit() async {
    if (!Platform.isMacOS) return;
    setState(() => _hkStatus = 'Načítám HomeKit…');
    final list = await HomeKitBridge.listLights();
    if (!mounted) return;
    setState(() {
      _hkLights = list;
      _hkStatus = list.isEmpty ? 'Žádná HomeKit světla (nebo chybí oprávnění).' : '${list.length} světel.';
    });
  }

  void _patch(SmartLightsSettings next) => widget.onSmartLightsChanged(next);

  @override
  Widget build(BuildContext context) {
    final sl = _sl;
    final innerMax = AppBreakpoints.maxContentWidth(widget.maxWidth).clamp(280.0, widget.maxWidth);
    final scheme = Theme.of(context).colorScheme;

    Future<void> pickHaLight() async {
      if (sl.haBaseUrl.trim().isEmpty || sl.haLongLivedToken.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nejdřív nastav URL a token Home Assistant.')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('HA: $err')));
        return;
      }
      final lights = states.where((e) => (e['entity_id'] as String?)?.startsWith('light.') ?? false).toList();
      if (lights.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('V HA nejsou žádné entity light.*')),
        );
        return;
      }
      final picked = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Přidat světlo z Home Assistant'),
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
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušit'))],
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
              Text('Chytrá domácnost', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Home Assistant: přímé ovládání entit light.* přes REST. '
                'Apple Home (HomeKit): nativně na macOS. '
                'Google Home: žádné veřejné lokální API — použij propojení přes Home Assistant (viz níže).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Posílat barvy na chytrá světla'),
                subtitle: const Text('Zapni až po nastavení HA / HomeKit fixture níže.'),
                value: sl.enabled,
                onChanged: (v) => _patch(sl.copyWith(enabled: v)),
              ),
              const Divider(height: 32),
              Text('Home Assistant', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: sl.haBaseUrl,
                decoration: const InputDecoration(
                  labelText: 'URL (https://…:8123)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _patch(sl.copyWith(haBaseUrl: v.trim())),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('ha_tok_${sl.haLongLivedToken.isNotEmpty}'),
                initialValue: sl.haLongLivedToken,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Long-lived access token',
                  helperText: 'Ukládá se mimo default.json (application support / ha_long_lived_token.txt).',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _patch(sl.copyWith(haLongLivedToken: v)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Důvěřovat vlastnímu HTTPS certifikátu'),
                subtitle: const Text('Jen lokální HA s self-signed certem.'),
                value: sl.haAllowInsecureCert,
                onChanged: (v) => _patch(sl.copyWith(haAllowInsecureCert: v)),
              ),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _testHa,
                    icon: const Icon(Icons.wifi_protected_setup),
                    label: const Text('Test spojení'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: pickHaLight,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Přidat světlo z HA'),
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
                      decoration: const InputDecoration(
                        labelText: 'Max. Hz na světlo',
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'Strop jasu %',
                        border: OutlineInputBorder(),
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
              Text('Apple Home (HomeKit)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (!Platform.isMacOS)
                Text(
                  'Nativní HomeKit je jen na macOS. Na Windows/Linux přidej světla do Home Assistant '
                  '(HomeKit Device / Matter bridge) a ovládej je přes HA výše.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else ...[
                Text(_hkStatus, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _refreshHomeKit,
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Obnovit seznam HomeKit světel'),
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
              Text('Google Home', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Google nepovoluje desktopové aplikaci přímo řídit „Google Home“ světla. '
                'Spolehlivá cesta: nainstaluj Home Assistant, přidej tam Hue / Nest / … a propoj HA s Google Assistant.',
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
                    label: const Text('Dokumentace: Google Assistant + HA'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl('https://my.home-assistant.io/'),
                    icon: const Icon(Icons.link),
                    label: const Text('My Home Assistant'),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text('Virtuální místnost', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Umísti TV, sebe a světla v plánku. Kužel ukazuje směr pohledu (relativně k ose k TV). '
                'Vlna mění jas podle vzdálenosti od TV a času — signály na HA/HomeKit jdou každý snímek přes stávající mapování barev.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              VirtualRoomEditor(sl: sl, onChanged: _patch),
              const Divider(height: 32),
              Text('Nakonfigurovaná světla (${sl.fixtures.length})', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (sl.fixtures.isEmpty)
                Text('Zatím žádná — přidej z HA nebo HomeKit.', style: Theme.of(context).textTheme.bodySmall),
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
                                tooltip: 'Odebrat',
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
                                ? 'HA: ${f.haEntityId}'
                                : 'HomeKit: ${f.homeKitAccessoryUuid}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          DropdownButtonFormField<SmartBindingKind>(
                            value: f.binding.kind,
                            decoration: const InputDecoration(labelText: 'Mapování barvy'),
                            items: const [
                              DropdownMenuItem(value: SmartBindingKind.globalMean, child: Text('Průměr všech LED')),
                              DropdownMenuItem(
                                value: SmartBindingKind.virtualLedRange,
                                child: Text('Rozsah LED na zařízení'),
                              ),
                              DropdownMenuItem(value: SmartBindingKind.screenEdge, child: Text('Hrana obrazovky')),
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
                              decoration: const InputDecoration(
                                labelText: 'device_id (prázdné = první zařízení)',
                                border: OutlineInputBorder(),
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
                                    decoration: const InputDecoration(labelText: 'led_start', border: OutlineInputBorder()),
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
                                    decoration: const InputDecoration(labelText: 'led_end', border: OutlineInputBorder()),
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
                              decoration: const InputDecoration(labelText: 'Hrana'),
                              items: const [
                                DropdownMenuItem(value: 'left', child: Text('Levá')),
                                DropdownMenuItem(value: 'right', child: Text('Pravá')),
                                DropdownMenuItem(value: 'top', child: Text('Horní')),
                                DropdownMenuItem(value: 'bottom', child: Text('Spodní')),
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
                              decoration: const InputDecoration(
                                labelText: 'monitor_index (0=desktop, 1…)',
                                border: OutlineInputBorder(),
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
                            title: const Text('Zapnuto'),
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
