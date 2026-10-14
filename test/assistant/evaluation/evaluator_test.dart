import 'dart:convert';
import 'dart:io';

import 'package:assistant_poc/assistant/evaluation/eval_dataset.dart';
import 'package:assistant_poc/assistant/evaluation/evaluator.dart';
import 'package:assistant_poc/assistant/models/action_prediction.dart';
import 'package:assistant_poc/assistant/providers/assistant_model.dart';
import 'package:assistant_poc/assistant/providers/model_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

/// Model double whose behaviour is a function of the input; used only to test
/// the scoring logic itself (never to produce Phase 2 results).
class ScriptedModel implements TracedAssistantModel {
  ScriptedModel(this._f);
  final ActionPrediction Function(String) _f;
  @override
  String get modelName => 'scripted';
  @override
  Map<String, Object?> get runtimeInfo => {'model': 'scripted'};
  @override
  Future<ActionPrediction> interpret(String i) async => _f(i);
  @override
  Future<ModelInterpretation> interpretWithTrace(String i) async =>
      ModelInterpretation(
        prediction: _f(i),
        rawOutput: 'scripted',
        latency: const Duration(milliseconds: 5),
      );
}

ActionPrediction call(String a, Map<String, Object?> p) =>
    ActionPrediction(status: 'success', action: a, parameters: p);
const none = ActionPrediction(
  status: 'unsupported',
  action: null,
  parameters: <String, Object?>{},
);

EvalCase theme(String id, String mode, {String lang = 'english'}) => EvalCase(
  id: id,
  language: lang,
  input: id,
  expected: ExpectedResult(
    status: 'success',
    action: 'change_theme',
    parameters: {'mode': mode},
    acceptableStatuses: const ['success'],
  ),
);

EvalCase negative(String id, {bool clarify = false}) => EvalCase(
  id: id,
  language: 'english',
  input: id,
  expected: ExpectedResult(
    status: clarify ? 'clarification_required' : 'unsupported',
    action: null,
    parameters: const {},
    acceptableStatuses: clarify
        ? const ['clarification_required', 'unsupported']
        : const ['unsupported'],
  ),
);

void main() {
  Future<EvalReport> run(
    List<EvalCase> cases,
    ActionPrediction Function(String) f,
  ) => Evaluator(model: ScriptedModel(f)).run(EvalDataset('t', 1, cases));

  test('perfect model scores 100% with no failures', () async {
    final r = await run([
      theme('a', 'dark'),
      negative('b'),
    ], (i) => i == 'a' ? call('change_theme', {'mode': 'dark'}) : none);
    final m = r.metrics();
    expect(m['actionAccuracyPct'], 100);
    expect(m['parameterAccuracyPct'], 100);
    expect(m['fullPredictionAccuracyPct'], 100);
    expect(m['invalidOutputRatePct'], 0);
    expect(m['fabricatedParameterRatePct'], 0);
  });

  test(
    'wrong in-domain parameter: action ok, parameter wrong, not fabricated',
    () async {
      final r = await run([
        theme('a', 'dark'),
      ], (_) => call('change_theme', {'mode': 'light'}));
      final c = r.cases.single;
      expect(c.actionCorrect, isTrue);
      expect(c.parametersCorrect, isFalse);
      expect(c.fullPredictionCorrect, isFalse);
      expect(c.fabricatedParameter, isFalse);
      expect(c.failureCategory!.wireName, 'wrong_parameter');
    },
  );

  test('value for a request with no basis is fabricated', () async {
    final r = await run([
      negative('change the theme', clarify: true),
    ], (_) => call('change_theme', {'mode': 'dark'}));
    expect(r.cases.single.fabricatedParameter, isTrue);
    expect(r.cases.single.failureCategory!.wireName, 'fabricated_parameter');
    expect(r.cases.single.executed, isTrue); // valid but wrong: still a failure
    expect(r.metrics()['fullPredictionAccuracyPct'], 0);
  });

  test(
    'invented value is rejected safely, counted invalid + fabricated, never executed',
    () async {
      final r = await run([
        negative('open facebook'),
      ], (_) => call('navigate', {'destination': 'facebook'}));
      final c = r.cases.single;
      expect(c.invalidOutput, isTrue);
      expect(c.fabricatedParameter, isTrue);
      expect(c.executed, isFalse);
      expect(
        c.failureCategory!.wireName,
        'unsupported_request_mapped_to_action',
      );
      expect(r.metrics()['environmentCalls'], 0);
    },
  );

  test('non-exposed real action is rejected and not executed', () async {
    final r = await run([
      negative('x'),
    ], (_) => call('change_language', {'language': 'ar'}));
    expect(r.cases.single.executed, isFalse);
    expect(r.cases.single.invalidOutput, isTrue);
  });

  test('clarification expected: refusal also acceptable', () async {
    final r = await run([negative('change theme', clarify: true)], (_) => none);
    expect(r.cases.single.fullPredictionCorrect, isTrue);
  });

  test('missed intent is classified by language', () async {
    final r = await run([
      theme('en', 'dark'),
      theme('ar', 'dark', lang: 'egyptian_arabic'),
      theme('mx', 'dark', lang: 'mixed'),
    ], (_) => none);
    expect(
      [for (final c in r.cases) c.failureCategory!.wireName],
      ['wrong_action', 'language_failure', 'mixed_language_failure'],
    );
  });

  test('throwing model is recorded as malformed, not crash', () async {
    final r = await Evaluator(
      model: _Throwing(),
    ).run(EvalDataset('t', 1, [theme('a', 'dark')]));
    expect(r.cases.single.failureCategory!.wireName, 'malformed_output');
    expect(r.cases.single.executed, isFalse);
  });

  test('uncontrolled executions are always zero', () async {
    final r = await run([
      theme('a', 'dark'),
      negative('b'),
    ], (i) => call('navigate', {'destination': 'nowhere'}));
    expect(r.metrics()['uncontrolledExecutions'], 0);
  });

  group('phase_2_v1 dataset hygiene', () {
    final raw = File('evaluation/datasets/phase_2_v1.json').readAsStringSync();
    final ds = EvalDataset.parse(raw);

    test('has 50+ commands, unique ids, both actions, each language group', () {
      expect(ds.cases.length, greaterThanOrEqualTo(50));
      expect(ds.cases.map((c) => c.id).toSet().length, ds.cases.length);
      expect(
        ds.cases.where((c) => c.expected.action == 'change_theme'),
        isNotEmpty,
      );
      expect(
        ds.cases.where((c) => c.expected.action == 'navigate'),
        isNotEmpty,
      );
      for (final l in ['english', 'msa_arabic', 'egyptian_arabic', 'mixed']) {
        expect(
          ds.cases.where((c) => c.language == l).length,
          inInclusiveRange(12, 20),
          reason: l,
        );
      }
    });

    test('no dataset input appears in the few-shot examples (no leakage)', () {
      String n(String s) => s.trim().toLowerCase();
      final shots = assistantFewShotExamples.map((e) => n(e.$1)).toSet();
      expect(ds.cases.where((c) => shots.contains(n(c.input))), isEmpty);
    });

    test('expected values only use the Phase 2 action contract', () {
      for (final c in ds.cases.where((c) => c.expected.isSuccess)) {
        expect(['change_theme', 'navigate'], contains(c.expected.action));
      }
      expect(jsonDecode(raw), isA<Map>());
    });
  });
}

class _Throwing implements TracedAssistantModel {
  @override
  String get modelName => 'throwing';
  @override
  Map<String, Object?> get runtimeInfo => {};
  @override
  Future<ActionPrediction> interpret(String i) => throw StateError('boom');
  @override
  Future<ModelInterpretation> interpretWithTrace(String i) =>
      throw StateError('boom');
}
