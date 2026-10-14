import 'dart:async';

import 'package:flutter/material.dart';

import 'eval_progress.dart';

/// Full-screen live view of an on-device evaluation: what stage it is in, which
/// command is being processed, what the model answered, and how the numbers
/// stand, in plain language. Replaces the harness's blank "Test starting…".
class EvalProgressApp extends StatelessWidget {
  const EvalProgressApp({super.key, required this.progress});
  final EvalProgress progress;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7C7CFF),
      ),
      home: EvalProgressScreen(progress: progress),
    );
  }
}

class EvalProgressScreen extends StatefulWidget {
  const EvalProgressScreen({super.key, required this.progress});
  final EvalProgress progress;

  @override
  State<EvalProgressScreen> createState() => _EvalProgressScreenState();
}

class _EvalProgressScreenState extends State<EvalProgressScreen> {
  Timer? _tick;
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  String? _lastActive;
  bool _showSanity = false;

  @override
  void initState() {
    super.initState();
    // Keeps the elapsed-time label moving during long native calls.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the dataset that just became active into view, so nothing important
  /// is hidden below the fold. The user can still scroll freely afterwards.
  void _followActive(EvalProgress p) {
    final name = p.current?.name;
    if (name == null || name == _lastActive) return;
    _lastActive = name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[name]?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.02,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  static const _steps = [
    (EvalStage.downloading, Icons.cloud_download_rounded, 'Get model'),
    (EvalStage.loading, Icons.memory_rounded, 'Load'),
    (EvalStage.sanity, Icons.fact_check_rounded, 'Check'),
    (EvalStage.evaluating, Icons.analytics_rounded, 'Evaluate'),
    (EvalStage.finished, Icons.flag_rounded, 'Results'),
  ];

  int _stepIndex(EvalStage s) => switch (s) {
    EvalStage.preparing => -1,
    EvalStage.downloading => 0,
    EvalStage.loading => 1,
    EvalStage.sanity => 2,
    EvalStage.evaluating => 3,
    EvalStage.finished => 4,
    EvalStage.failed => -2,
  };

  String _explain(EvalProgress p) => switch (p.stage) {
    EvalStage.preparing => 'Getting ready.',
    EvalStage.downloading =>
      'Downloading the model once from Hugging Face. After this it runs without internet.',
    EvalStage.loading =>
      'Loading the model into memory. Nothing is sent anywhere; inference is local.',
    EvalStage.sanity =>
      'Quick end-to-end check: a few sample commands go through the model, the validator and the executor.',
    EvalStage.evaluating =>
      'Each command goes: model -> validator -> action registry -> executor (a counting stand-in, never the real app). Then it is compared with the answer written down beforehand.',
    EvalStage.finished => 'Finished. Results were saved from the log.',
    EvalStage.failed =>
      'The run stopped with an error. Nothing was executed unsafely.',
  };

  static bool _rtl(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);

  String _elapsed(EvalProgress p) {
    final d = DateTime.now().difference(p.startedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.progress,
      builder: (context, _) {
        final p = widget.progress;
        _followActive(p);
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF14142B),
                  Color(0xFF1F1B3D),
                  Color(0xFF0E1F2E),
                ],
              ),
            ),
            child: SafeArea(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _header(context, p, scheme),
                    const SizedBox(height: 18),
                    _stepper(context, p, scheme),
                    const SizedBox(height: 14),
                    _explainCard(context, p, scheme),
                    const SizedBox(height: 14),
                    if (p.stage == EvalStage.downloading)
                      _downloadCard(context, p, scheme),
                    if (p.stage == EvalStage.sanity || p.sanity.isNotEmpty)
                      _sanityCard(context, p, scheme),
                    if (p.datasets.isNotEmpty) ..._datasets(context, p, scheme),
                    if (p.stage == EvalStage.failed)
                      _errorCard(context, p, scheme),
                    const SizedBox(height: 8),
                    _safetyBadge(context, p, scheme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, EvalProgress p, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On-device evaluation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Elapsed ${_elapsed(p)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(Icons.memory_rounded, p.modelName),
            _chip(Icons.edit_note_rounded, p.promptId),
            _chip(Icons.phone_iphone_rounded, p.device),
          ],
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12.5)),
      ],
    ),
  );

  Widget _stepper(BuildContext context, EvalProgress p, ColorScheme scheme) {
    final idx = _stepIndex(p.stage);
    final failed = p.stage == EvalStage.failed;
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: failed && i == 0
                        ? scheme.error
                        : i < idx || p.stage == EvalStage.finished
                        ? const Color(0xFF2DBE7E)
                        : i == idx
                        ? scheme.primary
                        : Colors.white12,
                    boxShadow: i == idx
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.5),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: i == idx && p.stage != EvalStage.finished
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          i < idx || p.stage == EvalStage.finished
                              ? Icons.check_rounded
                              : _steps[i].$2,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].$3,
                  style: TextStyle(
                    fontSize: 11,
                    color: i <= idx ? Colors.white : Colors.white38,
                    fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(Widget child, {Color? color}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );

  Widget _explainCard(
    BuildContext context,
    EvalProgress p,
    ColorScheme scheme,
  ) {
    return _card(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _explain(p),
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _downloadCard(
    BuildContext context,
    EvalProgress p,
    ColorScheme scheme,
  ) {
    final v = p.downloadPercent;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_download_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                v == null ? 'Downloading…' : 'Downloading $v%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: v == null ? null : v / 100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sanityCard(BuildContext context, EvalProgress p, ColorScheme scheme) {
    final expanded = p.stage == EvalStage.sanity || _showSanity;
    if (!expanded) {
      // Finished: one line, tap to expand, so the datasets stay visible.
      final ok = p.sanity.where((c) => c.executed).length;
      return GestureDetector(
        onTap: () => setState(() => _showSanity = true),
        child: _card(
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2DBE7E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quick check passed: $ok of ${p.sanity.length} commands ran through the full pipeline',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: Colors.white54),
            ],
          ),
        ),
      );
    }
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick check (${p.sanity.length} commands)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final c in p.sanity) _caseRow(c),
          if (p.stage == EvalStage.sanity && p.nowInput != null)
            _nowRow(p.nowInput!),
        ],
      ),
    );
  }

  List<Widget> _datasets(
    BuildContext context,
    EvalProgress p,
    ColorScheme scheme,
  ) {
    return [
      for (final d in p.datasets)
        KeyedSubtree(
          key: _keys.putIfAbsent(d.name, GlobalKey.new),
          child: _datasetCard(context, p, d, d == p.current, scheme),
        ),
    ];
  }

  Widget _datasetCard(
    BuildContext context,
    EvalProgress p,
    DatasetProgress d,
    bool active,
    ColorScheme scheme,
  ) {
    final fin = d.done >= d.total;
    final pct = d.done == 0 ? 0.0 : 100 * d.correct / d.done;
    final apct = d.done == 0 ? 0.0 : 100 * d.actionCorrect / d.done;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fin
                    ? Icons.check_circle_rounded
                    : active
                    ? Icons.play_circle_fill_rounded
                    : Icons.schedule_rounded,
                color: fin
                    ? const Color(0xFF2DBE7E)
                    : active
                    ? scheme.primary
                    : Colors.white38,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${d.done}/${d.total}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: d.total == 0 ? 0 : d.done / d.total,
            ),
          ),
          if (d.done > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('Action', '${apct.toStringAsFixed(1)}%'),
                _stat('Full', '${pct.toStringAsFixed(1)}%'),
                _stat('Asked you', '${d.asked}'),
                _stat('Executed', '${d.executed}'),
              ],
            ),
          ],
          if (active &&
              p.stage == EvalStage.evaluating &&
              p.nowInput != null) ...[
            const SizedBox(height: 10),
            _nowRow(p.nowInput!),
          ],
          if (active && p.recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final c in p.recent.reversed.take(5)) _caseRow(c),
          ],
          if (fin && d.metrics != null) ...[
            const SizedBox(height: 10),
            Text(
              _summary(d.metrics!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
      color: active ? Colors.white.withValues(alpha: 0.11) : null,
    );
  }

  String _summary(Map<String, Object?> m) {
    String f(String k) => (m[k] as num).toStringAsFixed(1);
    return 'Action ${f('actionAccuracyPct')}% · Parameters ${f('parameterAccuracyPct')}% · Full ${f('fullPredictionAccuracyPct')}%\n'
        'Invalid output ${f('invalidOutputRatePct')}% · Fabricated ${f('fabricatedParameterRatePct')}% · '
        'Asked the user ${m['askedUserCases']} · Uncontrolled executions ${m['uncontrolledExecutions']}';
  }

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    ),
  );

  Widget _nowRow(String input) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Interpreting: $input',
            textDirection: _rtl(input) ? TextDirection.rtl : TextDirection.ltr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    ),
  );

  Widget _caseRow(LiveCase c) {
    final color = c.correct ? const Color(0xFF2DBE7E) : const Color(0xFFFFB454);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            c.correct ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.input,
                  textDirection: _rtl(c.input)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${c.output}  ·  ${c.latencyMs} ms${c.executed ? '  ·  executed' : '  ·  not executed'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                ),
                if (!c.correct && c.note.isNotEmpty)
                  Text(
                    c.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: color),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, EvalProgress p, ColorScheme scheme) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error),
              const SizedBox(width: 8),
              const Text(
                'Error',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            p.error ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
      color: scheme.errorContainer.withValues(alpha: 0.25),
    );
  }

  Widget _safetyBadge(
    BuildContext context,
    EvalProgress p,
    ColorScheme scheme,
  ) {
    final ok = p.uncontrolled == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (ok ? const Color(0xFF2DBE7E) : scheme.error).withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.verified_user_rounded : Icons.warning_rounded,
            color: ok ? const Color(0xFF2DBE7E) : scheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Safety: ${p.uncontrolled} uncontrolled executions. Nothing ran without passing validation.'
                  : 'Safety problem: ${p.uncontrolled} executions without validation!',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
