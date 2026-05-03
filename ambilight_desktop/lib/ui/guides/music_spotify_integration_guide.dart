import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/ambilight_app_controller.dart';

/// Krátký průvodce: režim Hudba, Spotify, barvy z Windows (GSMTC).
class MusicSpotifyIntegrationGuide {
  MusicSpotifyIntegrationGuide._();

  static const _kSpotifyDashboard = 'https://developer.spotify.com/dashboard';

  static Future<void> show(BuildContext parentContext) {
    final mq = MediaQuery.sizeOf(parentContext);
    final w = (mq.width - 40).clamp(320.0, 520.0);
    final h = (mq.height * 0.9).clamp(380.0, 680.0);

    return showDialog<void>(
      context: parentContext,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;
        final ctrl = parentContext.read<AmbilightAppController>();

        Widget card({
          required String title,
          required String body,
          List<Widget>? footer,
        }) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: scheme.onSurface.withValues(alpha: 0.92),
                    ),
                  ),
                  if (footer != null && footer.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: footer),
                  ],
                ],
              ),
            ),
          );
        }

        Future<void> openSpotifyDashboard() async {
          final u = Uri.parse(_kSpotifyDashboard);
          if (!await launchUrl(u, mode: LaunchMode.externalApplication) && parentContext.mounted) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              const SnackBar(content: Text('Otevření prohlížeče se nezdařilo.')),
            );
          }
        }

        Future<void> startSpotifyBrowserLogin() async {
          final cid = ctrl.config.spotify.clientId;
          if (cid == null || cid.trim().isEmpty) {
            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                const SnackBar(
                  content: Text('Nejdřív v Nastavení → Spotify zadej Client ID (viz tlačítko výše).'),
                ),
              );
            }
            return;
          }
          Navigator.of(dialogContext).pop();
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!parentContext.mounted) return;
          await parentContext.read<AmbilightAppController>().spotifyConnect();
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: w,
            height: h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 4, 10),
                  child: Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hudba a barvy z obalu',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Zavřít',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    children: [
                      Text(
                        'Stručně: v režimu Hudba jde o zvuk z PC (efekty) a volitelně jedna barva z obalu skladby.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      card(
                        title: '1 · Režim a zvuk',
                        body:
                            'Na přehledu zapni dlaždici „Hudba“. V Nastavení → Hudba vyber vstup (Stereo Mix, mikrofon, …) a v systému povol nahrávání zvuku pro AmbiLight.',
                      ),
                      card(
                        title: '2 · Barva z obalu',
                        body:
                            'Buď Spotify (níže), nebo na Windows sekce „OS médium“ v Nastavení → Spotify (Apple Music apod. přes systém). '
                            'Když je obal zapnutý, má přednost před „tančícími“ efekty z FFT.',
                      ),
                      card(
                        title: '3 · Spotify',
                        body:
                            'Potřebuješ Client ID z vývojářské konzole a v konzoli redirect http://127.0.0.1:8767/callback. '
                            'Tlačítkem níže otevřeš web — přihlášení k účtu Spotify pak spustí prohlížeč stejně jako „Přihlásit“ na přehledu.',
                        footer: [
                          OutlinedButton.icon(
                            onPressed: openSpotifyDashboard,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Otevřít Spotify Developer'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: startSpotifyBrowserLogin,
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('Přihlásit Spotify v prohlížeči'),
                          ),
                        ],
                      ),
                      card(
                        title: '4 · Apple Music',
                        body:
                            'Žádné tlačítko „přihlásit Apple Music ve webu“ zde nepřidáme: Apple nemá pro tuto desktopovou aplikaci stejné otevřené OAuth jako Spotify. '
                            'Na Windows zapni „OS médium“, pusť Apple Music (aplikace) a hraj — barva se bere z miniatury, kterou systém sdílí (když ji hráč pošle).',
                      ),
                      card(
                        title: 'Když něco nejde',
                        body:
                            'Spotify chyba po přihlášení → zkus znovu Přihlásit. Žádný zvuk v efektech → špatný vstup nebo oprávnění. Pořád jen FFT → vypnutá integrace obalu nebo nic nehraje / chybí miniatura.',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Zavřít'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
