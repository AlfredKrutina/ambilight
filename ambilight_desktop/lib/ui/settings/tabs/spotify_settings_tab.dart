import 'package:flutter/material.dart';

import '../../../core/models/config_models.dart';
import '../../layout_breakpoints.dart';

/// D8 — `SpotifySettings` (OAuth a tokeny doplní A5; zde jen bezpečné pole bez zobrazení tajemství).
class SpotifySettingsTab extends StatelessWidget {
  const SpotifySettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<SpotifySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = draft.spotify;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);
    final hasAccess = s.accessToken != null && s.accessToken!.isNotEmpty;
    final hasRefresh = s.refreshToken != null && s.refreshToken!.isNotEmpty;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Spotify', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'OAuth tokény se do disku ukládají přes ConfigRepository sanitizovaně; '
                'plný tok a tlačítka „Přihlásit“ přidá agent A5.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Spotify integrace zapnutá'),
                value: s.enabled,
                onChanged: (v) => onChanged(s.copyWith(enabled: v)),
              ),
              SwitchListTile(
                title: const Text('Barvy z alba'),
                value: s.useAlbumColors,
                onChanged: (v) => onChanged(s.copyWith(useAlbumColors: v)),
              ),
              TextFormField(
                initialValue: s.clientId ?? '',
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => onChanged(s.copyWith(clientId: v.trim().isEmpty ? null : v.trim())),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('spotify_cs_${s.clientSecret != null}'),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Client secret',
                  hintText: s.clientSecret != null && s.clientSecret!.isNotEmpty
                      ? 'Ponechte prázdné = beze změny; smažte v A5 nebo zadejte nový'
                      : 'Volitelné',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  if (v.isEmpty) return;
                  onChanged(s.copyWith(clientSecret: v));
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: (s.clientSecret != null && s.clientSecret!.isNotEmpty)
                      ? () => onChanged(s.copyWith(clearClientSecret: true))
                      : null,
                  child: const Text('Smazat client secret z draftu'),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  hasAccess ? Icons.check_circle : Icons.circle_outlined,
                  color: hasAccess ? Colors.green : null,
                ),
                title: const Text('Access token'),
                subtitle: Text(hasAccess ? 'Nastaven (skryto)' : 'Chybí'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  hasRefresh ? Icons.check_circle : Icons.circle_outlined,
                  color: hasRefresh ? Colors.green : null,
                ),
                title: const Text('Refresh token'),
                subtitle: Text(hasRefresh ? 'Nastaven (skryto)' : 'Chybí'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
