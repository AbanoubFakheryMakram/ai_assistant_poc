import 'dart:io';

import 'package:assistant_poc/assistant/evaluation/eval_dataset.dart';
import 'package:assistant_poc/assistant/evaluation/evaluator.dart';
import 'package:assistant_poc/assistant/models/action_prediction.dart';
import 'package:assistant_poc/assistant/providers/assistant_model.dart';
import 'package:assistant_poc/assistant/providers/model_output_adapter.dart';
import 'package:assistant_poc/assistant/providers/model_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

class _Out implements TracedAssistantModel {
  _Out(this.f);
  final RawModelOutput Function(String) f;
  @override
  String get modelName => 'scripted';
  @override
  Map<String, Object?> get runtimeInfo => {};
  @override
  Future<ActionPrediction> interpret(String i) async =>
      (await interpretWithTrace(i)).prediction;
  @override
  Future<ModelInterpretation> interpretWithTrace(String i) async {
    final raw = f(i);
    return ModelInterpretation(
      prediction: const ModelOutputAdapter().adapt(raw),
      rawOutput: raw.describe(),
      latency: Duration.zero,
      outputKind: raw.kind,
    );
  }
}

EvalCase vague(String id, String target) => EvalCase(
  id: id,
  language: 'english',
  input: id,
  expected: ExpectedResult(
    status: 'clarification_required',
    action: null,
    parameters: const {},
    acceptableStatuses: const ['clarification_required', 'unsupported'],
    clarifyTarget: target,
  ),
);

EvalCase refusal(String id) => EvalCase(
  id: id,
  language: 'english',
  input: id,
  expected: const ExpectedResult(
    status: 'unsupported',
    action: null,
    parameters: {},
    acceptableStatuses: ['unsupported'],
  ),
);

RawModelOutput ask(String t) => RawModelOutput(
  calls: [
    RawFunctionCall('ask_user', {'target': t}),
  ],
);

void main() {
  test(
    'asking the user about a vague request is a correct, fully scored answer',
    () async {
      final r = await Evaluator(
        model: _Out((_) => ask('change_theme.mode')),
      ).run(EvalDataset('t', 1, [vague('a', 'change_theme.mode')]));
      final c = r.cases.single;
      expect(c.fullPredictionCorrect, isTrue);
      expect(c.parametersCorrect, isTrue);
      expect(c.clarifyTargetCorrect, isTrue);
      expect(c.fabricatedParameter, isFalse);
      expect(c.executed, isFalse);
      final m = r.metrics();
      expect(m['askedUserOfVagueCases'], 1);
      expect(m['askedUserWithCorrectTarget'], 1);
      expect(m['askedUserWhereNotExpected'], 0);
    },
  );

  test(
    'asking about the wrong value is still a question, but the target is marked wrong',
    () async {
      final r = await Evaluator(
        model: _Out((_) => ask('navigate.destination')),
      ).run(EvalDataset('t', 1, [vague('a', 'change_theme.mode')]));
      expect(r.cases.single.clarifyTargetCorrect, isFalse);
      expect(r.metrics()['askedUserWithCorrectTarget'], 0);
    },
  );

  test(
    'asking when the request should simply be declined counts as wrong',
    () async {
      final r = await Evaluator(
        model: _Out((_) => ask('change_theme.mode')),
      ).run(EvalDataset('t', 1, [refusal('send email')]));
      expect(r.cases.single.fullPredictionCorrect, isFalse);
      expect(r.metrics()['askedUserWhereNotExpected'], 1);
      expect(r.cases.single.executed, isFalse);
    },
  );

  test(
    'a made-up target is a question the app cannot offer: nothing runs',
    () async {
      final r = await Evaluator(
        model: _Out((_) => ask('delete_account.now')),
      ).run(EvalDataset('t', 1, [vague('a', 'change_theme.mode')]));
      expect(r.cases.single.executed, isFalse);
      expect(r.cases.single.clarifyTargetCorrect, isFalse);
      expect(r.metrics()['uncontrolledExecutions'], 0);
    },
  );

  test(
    'prompt v4 default tools: registry specs with the ask function only when allowed',
    () {
      expect(promptClarifyV4.id, 'clarify_prompt_v4');
      expect(promptVersionById('clarify_prompt_v4'), same(promptClarifyV4));
      expect(() => promptVersionById('nope'), throwsArgumentError);
    },
  );

  test(
    'held-out v3: 64 unique new cases, vague ones carry a clarification target',
    () {
      EvalDataset load(String n) => EvalDataset.parse(
        File('evaluation/datasets/$n.json').readAsStringSync(),
      );
      String n(String s) =>
          s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final h = load('phase_2_recovery_heldout_v3');
      expect(h.cases.length, 64);
      final hi = {for (final c in h.cases) n(c.input)};
      expect(hi.length, 64);
      for (final d in [
        'phase_2_v1',
        'phase_2_recovery_v1',
        'phase_2_recovery_heldout_v1',
        'phase_2_recovery_heldout_v2',
      ]) {
        expect(
          hi.intersection({for (final c in load(d).cases) n(c.input)}),
          isEmpty,
          reason: d,
        );
      }
      final examples = {
        for (final e in recoveryNegativeExamples) n(e),
        for (final e in assistantFewShotExamples) n(e.$1),
      };
      expect(hi.intersection(examples), isEmpty);
      final v = h.cases
          .where((c) => c.expected.status == 'clarification_required')
          .toList();
      expect(v.length, 16);
      expect(
        v.every(
          (c) => const [
            'change_theme.mode',
            'navigate.destination',
          ].contains(c.expected.clarifyTarget),
        ),
        isTrue,
      );
      for (final l in ['english', 'msa_arabic', 'egyptian_arabic', 'mixed']) {
        expect(h.cases.where((c) => c.language == l).length, 16);
      }
    },
  );
}
