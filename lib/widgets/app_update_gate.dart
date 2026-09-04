import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update_policy.dart';
import '../services/app_review_service.dart';
import '../services/app_update_service.dart';

/// Above the app Navigator, so widget/deep-link routes cannot cover the prompt.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate(
      {super.key, required this.child, this.check, this.openStore});
  final Widget child;
  final Future<AppUpdateDecision?> Function()? check;
  final Future<void> Function()? openStore;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  static const _dismissedVersionKey = 'update_prompt_dismissed_version_v1';
  static const _dismissedAtKey = 'update_prompt_dismissed_at_v1';
  AppUpdateDecision? _decision;
  bool _checking = false;
  bool _opening = false;
  String? _error;
  String? _dismissedInSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    AppUpdateDecision? decision;
    try {
      decision = await (widget.check ?? AppUpdateService().check)()
          .timeout(const Duration(seconds: 12));
      if (decision != null && !decision.required) {
        final prefs = await SharedPreferences.getInstance();
        final at = DateTime.tryParse(prefs.getString(_dismissedAtKey) ?? '');
        final recentlyDismissed =
            prefs.getString(_dismissedVersionKey) == decision.latestVersion &&
                at != null &&
                !DateTime.now().difference(at).isNegative &&
                DateTime.now().difference(at) < const Duration(days: 1);
        if (recentlyDismissed ||
            _dismissedInSession == decision.latestVersion) {
          decision = null;
        }
      }
    } catch (error) {
      debugPrint('Update prompt unavailable: $error');
    }
    if (!mounted) return;
    setState(() {
      _decision = decision;
      _checking = false;
    });
  }

  Future<void> _dismiss() async {
    final decision = _decision;
    if (decision == null || decision.required) return;
    setState(() {
      _dismissedInSession = decision.latestVersion;
      _decision = null;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, decision.latestVersion);
      await prefs.setString(_dismissedAtKey, DateTime.now().toIso8601String());
    } catch (_) {/* The current session dismissal still takes effect. */}
  }

  Future<void> _openStore() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await (widget.openStore ?? AppReviewService().openStoreListing)()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Mağaza açılamadı. İnternet bağlantını kontrol edip tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    return Stack(fit: StackFit.expand, children: [
      ExcludeFocus(
          excluding: decision != null,
          child: ExcludeSemantics(
              excluding: decision != null,
              child: IgnorePointer(
                  ignoring: decision != null, child: widget.child))),
      if (decision != null) ...[
        ModalBarrier(
            color: decision.required
                ? Theme.of(context).scaffoldBackgroundColor
                : Colors.black54,
            dismissible: !decision.required,
            onDismiss: _dismiss),
        SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.system_update, size: 48),
                    const SizedBox(height: 16),
                    Text(
                        decision.required
                            ? 'Güncelleme gerekli'
                            : 'Yeni sürüm hazır',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(
                        decision.required
                            ? 'Kullandığın sürüm artık desteklenmiyor. Devam etmek için uygulamayı mağazadan güncelle.'
                            : 'Her Gün İslam’ın ${decision.latestVersion} sürümü hazır. Yenilikler ve iyileştirmeler için güncelleyebilirsin.',
                        textAlign: TextAlign.center),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: _opening ? null : _openStore,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                                _opening ? 'Mağaza açılıyor…' : 'Güncelle'))),
                    if (!decision.required)
                      TextButton(
                          onPressed: _dismiss, child: const Text('Daha sonra')),
                    if (decision.required)
                      TextButton(
                          onPressed: _checking ? null : _refresh,
                          child: Text(_checking
                              ? 'Kontrol ediliyor…'
                              : 'Tekrar kontrol et')),
                  ])),
            ),
          ),
        ))),
      ],
    ]);
  }
}
