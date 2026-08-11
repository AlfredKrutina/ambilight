import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/ambilight_app_controller.dart';
import '../../application/build_environment.dart';
import '../../application/startup_crash_guard.dart';
import '../../l10n/context_ext.dart';
import '../../services/desktop_update/desktop_ota_report.dart';
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
    final writeErr = WindowsDesktopUpdater.preflightWritableInstallDir();
    if (writeErr != null) {
      await _showInstallFailure(writeErr);
      return;
    }
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
        final err = dl.error ?? l10n.desktopUpdateDownloadFailed;
        setState(() {
          _busy = false;
          _downloadError = err;
        });
        await _showInstallFailure(err);
        return;
      }

      // Progress dialog while launch cascade + heartbeat runs.
      unawaited(
        showDesktopOtaProgressDialog(
          context,
          message: l10n.desktopUpdateProgressPreparing,
        ),
      );

      await DesktopOtaReportStore.writePending(detail: 'Applying desktop update…');

      final started = await WindowsDesktopUpdater.launchExpandCopyRestart(
        zipFile: dl.zipFile!,
        waitPid: pid,
      );

      if (mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop(); // close progress
      }

      if (!mounted) return;
      if (!started.ok) {
        final err = started.error ?? l10n.desktopUpdateUpdaterStartFailed;
        await DesktopOtaReportStore.writeHostFailure(err);
        setState(() {
          _busy = false;
          _downloadError = '$err\n${started.logPath}';
        });
        await _showInstallFailure(err, logPath: started.logPath);
        return;
      }

      // Never exit unless THIS session's updater is still alive.
      final sid = started.sessionId ?? '';
      final alive = sid.isNotEmpty && await WindowsDesktopUpdater.isSessionHeartbeatAlive(sid);
      if (!alive) {
        const err =
            'Updater se nespustil spolehlive (chybi heartbeat). Aplikace zustava bezet.';
        await DesktopOtaReportStore.writeHostFailure(err);
        setState(() {
          _busy = false;
          _downloadError = '$err\n${started.logPath}';
        });
        await _showInstallFailure(err, logPath: started.logPath);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.desktopUpdateRestarting}${started.method != null ? ' (${started.method})' : ''}',
          ),
        ),
      );
      final ctrl = context.read<AmbilightAppController>();
      try {
        await ctrl.prepareQuitShutdownAsync();
      } catch (_) {}
      try {
        await ctrl.flushPersistToDisk();
      } catch (_) {}
      try {
        await StartupCrashGuard.markSessionClean();
      } catch (_) {}

      // Last chance abort — if updater died while we were saving, stay alive.
      final stillAlive = await WindowsDesktopUpdater.isSessionHeartbeatAlive(sid);
      if (!stillAlive) {
        const err =
            'Updater spadl pred ukoncenim aplikace. Nic se neprepisuje — app zustava bezet.';
        await DesktopOtaReportStore.writeHostFailure(err);
        if (mounted) {
          setState(() {
            _busy = false;
            _downloadError = '$err\n${started.logPath}';
          });
          await _showInstallFailure(err, logPath: started.logPath);
        }
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
      exit(0);
    } catch (e) {
      if (mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
        setState(() {
          _busy = false;
          _downloadError = '$e';
        });
        await DesktopOtaReportStore.writeHostFailure('$e');
        await _showInstallFailure('$e');
      }
    } finally {
      svc.close();
    }
  }

  Future<void> _showInstallFailure(String detail, {String? logPath}) async {
    if (!mounted) return;
    final path = logPath ?? WindowsDesktopUpdater.updateLogPath;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.desktopUpdateResultFailTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.l10n.desktopUpdateResultFailBody(detail)),
              const SizedBox(height: 12),
              Text(ctx.l10n.desktopUpdateLogPathLabel, style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(path, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final dir = Directory(WindowsDesktopUpdater.otaRoot);
              if (!await dir.exists()) await dir.create(recursive: true);
              await Process.run('explorer.exe', [dir.path]);
            },
            child: Text(ctx.l10n.openLogFolder),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.close),
          ),
        ],
      ),
    );
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
          if (Platform.isWindows) ...[
            const SizedBox(height: 6),
            SelectableText(
              WindowsDesktopUpdater.updateLogPath,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final dir = Directory(WindowsDesktopUpdater.otaRoot);
                  if (!await dir.exists()) {
                    await dir.create(recursive: true);
                  }
                  await Process.run('explorer.exe', [dir.path]);
                },
                icon: const Icon(Icons.folder_open, size: 16),
                label: Text(l10n.openLogFolder),
              ),
            ),
          ],
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
