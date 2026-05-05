import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/ambilight_app_controller.dart';
import '../../application/build_environment.dart';
import '../../l10n/context_ext.dart';
import '../../services/desktop_update/desktop_update_service.dart';
import '../../services/desktop_update/windows_desktop_updater.dart';

/// Kontrola aktualizace z manifestu (GitHub Release) a na Windows instalace po restartu.
class AboutDesktopUpdateCard extends StatefulWidget {
  const AboutDesktopUpdateCard({super.key});

  @override
  State<AboutDesktopUpdateCard> createState() => _AboutDesktopUpdateCardState();
}

class _AboutDesktopUpdateCardState extends State<AboutDesktopUpdateCard> {
  bool _busy = false;
  DesktopUpdateCheckResult? _result;
  String? _downloadError;
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInfo());
  }

  Future<void> _loadInfo() async {
    final i = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _info = i);
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _result = null;
      _downloadError = null;
    });
    final svc = DesktopUpdateService();
    try {
      final r = await svc.checkForUpdates(packageInfo: _info);
      if (!mounted) return;
      setState(() {
        _result = r;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = DesktopUpdateCheckParseError('$e');
        _busy = false;
      });
    } finally {
      svc.close();
    }
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url.trim());
    if (u == null || !u.hasScheme) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  Future<void> _windowsInstall(DesktopUpdateCheckAvailable a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.desktopUpdateConfirmTitle),
        content: Text(ctx.l10n.desktopUpdateConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.desktopUpdateConfirmInstall)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _downloadError = null;
    });
    final svc = DesktopUpdateService();
    final l10n = context.l10n;
    try {
      final dl = await svc.downloadVerifiedZip(a.asset);
      if (!mounted) return;
      if (!dl.isOk || dl.zipFile == null) {
        setState(() {
          _busy = false;
          _downloadError = dl.error ?? l10n.desktopUpdateDownloadFailed;
        });
        return;
      }
      final proc = await WindowsDesktopUpdater.launchExpandCopyRestart(
        zipFile: dl.zipFile!,
        waitPid: pid,
      );
      if (!mounted) return;
      if (proc == null) {
        setState(() {
          _busy = false;
          _downloadError = l10n.desktopUpdateUpdaterStartFailed;
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.desktopUpdateRestarting)),
      );
      final ctrl = context.read<AmbilightAppController>();
      await ctrl.flushPersistToDisk();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      exit(0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _downloadError = '$e';
        });
      }
    } finally {
      svc.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.desktopUpdateSectionTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          l10n.desktopUpdateSectionHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(l10n.desktopUpdateManifestUrlLabel, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        SelectableText(
          ambilightDesktopUpdateManifestUrl,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        if (_busy) const LinearProgressIndicator(minHeight: 3),
        if (!_busy)
          OutlinedButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.system_update_outlined, size: 18),
            label: Text(l10n.desktopUpdateCheckButton),
          ),
        if (_result != null) ..._resultWidgets(context),
        if (_downloadError != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.desktopUpdateErrorDetail(_downloadError!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ],
    );
  }

  List<Widget> _resultWidgets(BuildContext context) {
    final l10n = context.l10n;
    final r = _result!;
    return [
      const SizedBox(height: 10),
      switch (r) {
        DesktopUpdateCheckUpToDate() => Text(
            l10n.desktopUpdateUpToDate,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        DesktopUpdateCheckParseError(:final message) => Text(
            l10n.desktopUpdateCheckFailed(message),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        DesktopUpdateCheckChannelMismatch(:final manifestChannel, :final appChannel) => Text(
            l10n.desktopUpdateChannelMismatch(manifestChannel, appChannel),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
        final DesktopUpdateCheckAvailable a => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.desktopUpdateAvailable(a.manifest.version, a.currentVersion),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (a.manifest.releaseNotesUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => unawaited(_openUrl(a.manifest.releaseNotesUrl)),
                  child: Text(l10n.desktopUpdateReleaseNotesLink),
                ),
              ],
              const SizedBox(height: 8),
              if (Platform.isWindows && a.asset.kind == 'zip')
                FilledButton.icon(
                  onPressed: () => unawaited(_windowsInstall(a)),
                  icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: Text(l10n.desktopUpdateDownloadAndInstall),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    final url = a.manifest.releasePageUrl.isNotEmpty
                        ? a.manifest.releasePageUrl
                        : a.asset.url;
                    unawaited(_openUrl(url));
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.desktopUpdateOpenDownloadPage),
                ),
            ],
          ),
      },
    ];
  }
}
