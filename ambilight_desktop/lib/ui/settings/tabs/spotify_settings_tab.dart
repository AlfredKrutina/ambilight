import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/config_models.dart';
import '../../guides/music_spotify_integration_guide.dart';
import '../../layout_breakpoints.dart';

/// D8 — Spotify + volitelné barvy z OS přehrávače (Windows GSMTC: Apple Music, prohlížeč s YT Music, …).
class SpotifySettingsTab extends StatelessWidget {
  const SpotifySettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onSpotifyChanged,
    required this.onSystemMediaAlbumChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<SpotifySettings> onSpotifyChanged;
  final ValueChanged<SystemMediaAlbumSettings> onSystemMediaAlbumChanged;

  @override
  Widget build(BuildContext context) {
    final s = draft.spotify;
    final os = draft.systemMediaAlbum;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);
    final hasAccess = s.accessToken != null && s.accessToken!.isNotEmpty;
    final hasRefresh = s.refreshToken != null && s.refreshToken!.isNotEmpty;
    final winGsmtc = !kIsWeb && Platform.isWindows;

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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => MusicSpotifyIntegrationGuide.show(context),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Nápověda: hudba a obaly'),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Spotify integrace zapnutá'),
                value: s.enabled,
                onChanged: (v) => onSpotifyChanged(s.copyWith(enabled: v)),
              ),
              SwitchListTile(
                title: const Text('Barvy z alba (Spotify API)'),
                value: s.useAlbumColors,
                onChanged: (v) => onSpotifyChanged(s.copyWith(useAlbumColors: v)),
              ),
              TextFormField(
                initialValue: s.clientId ?? '',
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => onSpotifyChanged(s.copyWith(clientId: v.trim().isEmpty ? null : v.trim())),
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
                  onSpotifyChanged(s.copyWith(clientSecret: v));
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: (s.clientSecret != null && s.clientSecret!.isNotEmpty)
                      ? () => onSpotifyChanged(s.copyWith(clearClientSecret: true))
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
              const SizedBox(height: 28),
              Text('Apple Music / YouTube Music (OS)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                winGsmtc
                    ? 'Na Windows čteme náhled obalu z aktuálního systémového přehrávače (GSMTC). '
                        'Funguje typicky pro aplikaci Apple Music a často pro YouTube Music v Edge nebo Chrome — '
                        'záleží, zda prohlížeč nebo hráč miniaturu do systému pošle. Oficiální API YouTube Music zde není.'
                    : 'Na tomto OS zatím jen Spotify (OAuth). GSMTC / systémový náhled je implementovaný pro Windows.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: Text(winGsmtc ? 'Barva z obalu přes OS média (GSMTC)' : 'Barva z obalu přes OS média (nedostupné)'),
                subtitle: const Text('Použije se v music módu, pokud Spotify neposkytne barvu nebo je vypnuté.'),
                value: os.enabled && winGsmtc,
                onChanged: winGsmtc ? (v) => onSystemMediaAlbumChanged(os.copyWith(enabled: v)) : null,
              ),
              SwitchListTile(
                title: const Text('Použít dominantní barvu z miniatury OS'),
                value: os.useAlbumColors,
                onChanged: (v) => onSystemMediaAlbumChanged(os.copyWith(useAlbumColors: v)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
