import 'dart:convert';

import 'package:flutter/material.dart';

import '../../assistant/actions/action_registry.dart';
import '../../assistant/execution/action_executor.dart';
import '../../assistant/execution/assistant_pipeline.dart';
import '../../assistant/models/action_prediction.dart';
import '../../assistant/validation/action_validator.dart';
import '../../assistant/validation/validation_result.dart';
import '../app_state.dart';
import '../strings.dart';

/// Phase 1 tool: send a hand-written JSON prediction straight to the validator
/// and executor (the FULL registry, no AI involved). Useful for checking that
/// bad input is rejected and never executed.
class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key, required this.state, this.pipeline});
  final AppState state;
  final AssistantPipeline? pipeline;

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  static const _presets = <String, String>{
    'VALID theme dark':
        '{"status":"success","action":"change_theme","parameters":{"mode":"dark"}}',
    'VALID theme light':
        '{"status":"success","action":"change_theme","parameters":{"mode":"light"}}',
    'VALID language ar':
        '{"status":"success","action":"change_language","parameters":{"language":"ar"}}',
    'VALID language en':
        '{"status":"success","action":"change_language","parameters":{"language":"en"}}',
    'VALID go profile':
        '{"status":"success","action":"navigate","parameters":{"destination":"profile"}}',
    'VALID go settings':
        '{"status":"success","action":"navigate","parameters":{"destination":"settings"}}',
    'VALID notifications off':
        '{"status":"success","action":"toggle_notifications","parameters":{"enabled":false}}',
    'VALID search':
        '{"status":"success","action":"search","parameters":{"query":"medical equipment"}}',
    'BAD unknown action':
        '{"status":"success","action":"unknown_action","parameters":{}}',
    'BAD theme blue':
        '{"status":"success","action":"change_theme","parameters":{"mode":"blue"}}',
    'BAD route':
        '{"status":"success","action":"navigate","parameters":{"destination":"some-arbitrary-route"}}',
    'BAD enabled "yes"':
        '{"status":"success","action":"toggle_notifications","parameters":{"enabled":"yes"}}',
    'BAD extra param':
        '{"status":"success","action":"change_theme","parameters":{"mode":"dark","deleteEverything":true}}',
    'clarification':
        '{"status":"clarification_required","action":null,"parameters":{}}',
    'unsupported': '{"status":"unsupported","action":null,"parameters":{}}',
    'BAD malformed JSON': '{"status": "success", ',
  };

  late final AssistantPipeline _pipeline =
      widget.pipeline ??
      () {
        final registry = ActionRegistry.standard();
        return AssistantPipeline(
          ActionValidator(registry),
          ActionExecutor(registry, widget.state),
          registry: registry,
        );
      }();

  final _controller = TextEditingController(text: _presets.values.first);
  PipelineOutcome? _outcome;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await _pipeline.process(
      ActionPrediction.fromJsonString(_controller.text),
    );
    if (mounted) setState(() => _outcome = outcome);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings(widget.state.language);
    return Scaffold(
      appBar: AppBar(title: Text(s.devTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.devIntro, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _presets.entries)
                ActionChip(
                  label: Text(e.key),
                  onPressed: () => _controller.text = e.value,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('prediction_input'),
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('submit'),
            onPressed: _submit,
            child: Text(s.submitPrediction),
          ),
          const SizedBox(height: 16),
          if (_outcome != null) _OutcomeCard(outcome: _outcome!),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.outcome});
  final PipelineOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final p = outcome.prediction;
    final v = outcome.validation;
    final ex = outcome.execution;
    final accepted = v is ValidationAccepted;
    final lines = <String>[
      if (p.isMalformed)
        '→ (malformed input)'
      else ...[
        '→ ${p.action ?? 'no action'} (status: ${p.status})',
        if (p.parameters is Map)
          for (final e in (p.parameters as Map).entries)
            '→ ${e.key}: ${jsonEncode(e.value)}',
      ],
      accepted ? '→ VALIDATED' : '→ REJECTED',
      if (v is ValidationRejected) '→ ${v.reason.name}: ${v.message}',
      ex == null ? '→ NOT EXECUTED' : '→ EXECUTED (${ex.message})',
    ];
    final color = accepted ? Colors.green : Colors.red;
    return Card(
      key: const Key('outcome'),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              accepted ? 'VALID ACTION' : 'INVALID / NON-EXECUTABLE',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (final l in lines) Text(l, textDirection: TextDirection.ltr),
          ],
        ),
      ),
    );
  }
}
