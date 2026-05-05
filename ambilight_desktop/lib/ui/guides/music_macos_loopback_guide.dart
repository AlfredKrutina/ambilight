import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/context_ext.dart';

/// Průvodce: virtuální audio na macOS pro loopback (parita s Windows WASAPI mix).
class MusicMacosLoopbackGuide {
  MusicMacosLoopbackGuide._();

  static const _kBlackHole = 'https://existential.audio/blackhole/';

  static Future<void> show(BuildContext context) {
    final l10n = context.l10n;
    final mq = MediaQuery.sizeOf(context);
    final w = (mq.width - 40).clamp(320.0, 520.0);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return AlertDialog(
          title: Text(l10n.musicMacosLoopbackGuideTitle),
          content: SizedBox(
            width: w,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.musicMacosLoopbackGuideIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.musicMacosLoopbackGuideSteps,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.musicMacosLoopbackGuideNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.musicMacosLoopbackGuideClose),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final u = Uri.parse(_kBlackHole);
                if (!await launchUrl(u, mode: LaunchMode.externalApplication) && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.musicMacosLoopbackGuideOpenFailed)),
                  );
                }
              },
              child: Text(l10n.musicMacosLoopbackGuideBlackHole),
            ),
          ],
        );
      },
    );
  }
}
