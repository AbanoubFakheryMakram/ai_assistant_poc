import 'package:flutter/material.dart';

import '../../assistant/actions/clarification.dart';
import '../../assistant/execution/assistant_pipeline.dart';
import '../../assistant/models/action_parameters.dart';
import '../../assistant/validation/validation_result.dart';
import '../strings.dart';
import '../theme.dart';
import 'assistant_controller.dart';

/// What happened to one request: a human summary, the question if the user has
/// to choose, and (collapsed) the technical trace.
class TurnCard extends StatefulWidget {
  const TurnCard({
    super.key,
    required this.turn,
    required this.strings,
    required this.onChoose,
    required this.onDismissQuestion,
    required this.onClose,
  });

  final AssistantTurn turn;
  final Strings strings;
  final ValueChanged<String> onChoose;
  final VoidCallback onDismissQuestion;
  final VoidCallback onClose;

  @override
  State<TurnCard> createState() => _TurnCardState();
}

class _TurnCardState extends State<TurnCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.turn;
    final s = widget.strings;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('turn_card'),
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.input,
                    key: const Key('turn_input'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('turn_close'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 4),
            _Steps(turn: t, strings: s),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey('${t.status}-${t.chosen}'),
                  child: _body(context, t, s, scheme),
                ),
              ),
            ),
            if (t.interpretation != null || t.error != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                key: const Key('toggle_details'),
                onPressed: () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(s.details),
              ),
              if (_showDetails) _Details(turn: t, strings: s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AssistantTurn t,
    Strings s,
    ColorScheme scheme,
  ) {
    Widget line(IconData icon, Color color, String text, {Key? key}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            key: key,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
    switch (t.status) {
      case TurnStatus.thinking:
        return Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(s.thinking, key: const Key('turn_thinking')),
          ],
        );
      case TurnStatus.executed:
        return line(
          Icons.check_circle_rounded,
          scheme.success,
          _doneMessage(t.finalOutcome, s),
          key: const Key('turn_message'),
        );
      case TurnStatus.needsChoice:
        final offer = t.offer!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(
              Icons.help_rounded,
              scheme.primary,
              _question(offer, s),
              key: const Key('turn_message'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in offer.options)
                  ActionChip(
                    key: Key('choice_$o'),
                    label: Text(_optionLabel(offer, o, s)),
                    onPressed: () => widget.onChoose(o),
                  ),
                TextButton(
                  key: const Key('choice_none'),
                  onPressed: widget.onDismissQuestion,
                  child: Text(s.noneOfThese),
                ),
              ],
            ),
          ],
        );
      case TurnStatus.cannotDo:
        return line(
          Icons.info_rounded,
          scheme.primary,
          s.cannotDo,
          key: const Key('turn_message'),
        );
      case TurnStatus.rejected:
        return line(
          Icons.shield_rounded,
          scheme.warning,
          s.rejected,
          key: const Key('turn_message'),
        );
      case TurnStatus.failed:
        return line(
          Icons.error_rounded,
          scheme.error,
          s.failed,
          key: const Key('turn_message'),
        );
      case TurnStatus.dismissed:
        return line(
          Icons.undo_rounded,
          scheme.onSurfaceVariant,
          s.dismissed,
          key: const Key('turn_message'),
        );
    }
  }

  static String _question(ClarificationOffer o, Strings s) =>
      switch (o.target) {
        'change_theme.mode' => s.askTheme,
        'navigate.destination' => s.askDestination,
        _ => s.askGeneric,
      };

  static String _optionLabel(ClarificationOffer o, String option, Strings s) {
    switch (o.target) {
      case 'change_theme.mode':
        return s.themeName(ThemeModeOption.values.byName(option));
      case 'navigate.destination':
        return s.destination(AppDestination.values.byName(option));
      case 'change_language.language':
        return s.languageName(AppLanguage.values.byName(option));
    }
    return option;
  }

  /// A localized sentence built from the TYPED, validated parameters (never by
  /// parsing text).
  static String _doneMessage(PipelineOutcome? o, Strings s) {
    final v = o?.validation;
    if (v is! ValidationAccepted) return s.failed;
    return switch (v.validated.parameters) {
      ChangeThemeParameters(:final mode) => s.doneTheme(mode),
      NavigateParameters(:final destination) => s.doneNavigate(destination),
      ChangeLanguageParameters(:final language) => s.doneLanguage(language),
      ToggleNotificationsParameters(:final enabled) => s.doneNotifications(
        enabled,
      ),
      SearchParameters(:final query) => s.doneSearch(query),
    };
  }
}

/// Understood -> Checked -> Done, so it is visible that the app (not the model)
/// checks and executes.
class _Steps extends StatelessWidget {
  const _Steps({required this.turn, required this.strings});
  final AssistantTurn turn;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = turn.status;
    // (state: 0 pending, 1 active, 2 ok, 3 blocked)
    final (a, b, c) = switch (st) {
      TurnStatus.thinking => (1, 0, 0),
      TurnStatus.executed => (2, 2, 2),
      TurnStatus.needsChoice => (2, 2, 1),
      TurnStatus.dismissed => (2, 2, 3),
      TurnStatus.cannotDo || TurnStatus.rejected => (2, 3, 3),
      TurnStatus.failed => (3, 0, 0),
    };
    Widget step(String label, int state) {
      final color = switch (state) {
        2 => scheme.success,
        3 => scheme.warning,
        1 => scheme.primary,
        _ => scheme.outline,
      };
      final icon = switch (state) {
        2 => Icons.check_circle_rounded,
        3 => Icons.block_rounded,
        1 => Icons.radio_button_checked_rounded,
        _ => Icons.radio_button_unchecked_rounded,
      };
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    Widget bar() => Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: scheme.outlineVariant,
      ),
    );
    return Row(
      children: [
        step(strings.stepUnderstood, a),
        bar(),
        step(strings.stepChecked, b),
        bar(),
        step(strings.stepDone, c),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.turn, required this.strings});
  final AssistantTurn turn;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final i = turn.interpretation;
    final o = turn.finalOutcome;
    final p = i?.prediction;
    String predictionText() {
      if (p == null) return '-';
      if (p.isMalformed) return 'malformed (${p.malformedReason})';
      final params = p.parameters is Map
          ? (p.parameters as Map).entries
                .map((e) => '${e.key}=${e.value}')
                .join(', ')
          : '${p.parameters}';
      return '${p.status}: ${p.action ?? '-'}${params.isEmpty ? '' : ' ($params)'}';
    }

    final v = o?.validation;
    final validation = v is ValidationAccepted
        ? s.valid
        : v is ValidationRejected
        ? '${s.rejectedLabel}: ${v.reason.name}'
        : '-';
    final ex = o?.execution;
    final rows = <(String, String)>[
      (s.youSaid, turn.input),
      if (turn.error != null) ('Error', turn.error!),
      if (i != null) (s.modelOutput, i.rawOutput),
      if (i != null) (s.prediction, predictionText()),
      if (turn.chosen != null) ('Your choice', turn.chosen!),
      if (o != null) (s.validation, validation),
      if (o != null)
        (
          s.execution,
          ex == null ? s.notExecuted : '${s.executed}: ${ex.message}',
        ),
      if (i != null) (s.latency, '${i.latency.inMilliseconds} ms'),
    ];
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['monospace'],
    );
    return Container(
      key: const Key('turn_details'),
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (k, val) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$k: ',
                        style: mono?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: val, style: mono),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
