import 'dart:io';

import 'package:assistant_poc/assistant/evaluation/eval_dataset.dart';
import 'package:assistant_poc/assistant/evaluation/evaluator.dart';
import 'package:assistant_poc/assistant/models/action_prediction.dart';
import 'package:assistant_poc/assistant/providers/assistant_model.dart';
import 'package:assistant_poc/assistant/providers/flutter_gemma_assistant_model.dart';
import 'package:assistant_poc/assistant/providers/local_model_factory.dart';
import 'package:assistant_poc/assistant/providers/model_catalog.dart';
import 'package:assistant_poc/assistant/providers/model_output_adapter.dart';
import 'package:assistant_poc/assistant/providers/model_prompt.dart';
import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _Out implements TracedAssistantModel {
  _Out(this._f);
  final (ActionPrediction, ModelOutputKind) Function(String) _f;
  @override
  String get modelName => 'scripted';
  @override
  Map<String, Object?> get runtimeInfo => {};
  @override
  Future<ActionPrediction> interpret(String i) async => _f(i).$1;
  @override
  Future<ModelInterpretation> interpretWithTrace(String i) async {
    final (p, k) = _f(i);
    return ModelInterpretation(
      prediction: p,
      rawOutput: 'x',
      latency: Duration.zero,
      outputKind: k,
    );
  }
}

EvalCase c(String id, String lang, ExpectedResult e) =>
    EvalCase(id: id, language: lang, input: id, expected: e);
ExpectedResult theme(String m) => ExpectedResult(
  status: 'success',
  action: 'change_theme',
  parameters: {'mode': m},
  acceptableStatuses: const ['success'],
);
const refusal = ExpectedResult(
  status: 'unsupported',
  action: null,
  parameters: {},
  acceptableStatuses: ['unsupported'],
);

/// FNV-1a 64-bit, to prove frozen baseline files are byte-identical.
BigInt fnv(List<int> bytes) {
  final mask = (BigInt.one << 64) - BigInt.one;
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  for (final b in bytes) {
    h = ((h ^ BigInt.from(b)) * prime) & mask;
  }
  return h;
}

void main() {
  modelConfigTests();
  test('case JSON carries output kind and failure tags', () async {
    final r = await Evaluator(
      model: _Out(
        (_) => (
          const ActionPrediction(
            status: 'success',
            action: 'navigate',
            parameters: {'destination': 'profile'},
          ),
          ModelOutputKind.functionCall,
        ),
      ),
    ).run(EvalDataset('t', 1, [c('a', 'english', theme('dark'))]));
    final j = r.cases.single.toJson();
    expect(j['outputKind'], 'functionCall');
    expect(j['failureTags'], ['navigate_profile_collapse']);
  });

  test('adapter reports output kind and never picks one of several calls', () {
    const a = ModelOutputAdapter();
    const one = RawModelOutput(
      calls: [
        RawFunctionCall('navigate', {'destination': 'home'}),
      ],
    );
    const two = RawModelOutput(
      calls: [
        RawFunctionCall('navigate', {'destination': 'home'}),
        RawFunctionCall('navigate', {'destination': 'home'}),
      ],
    );
    expect(one.kind, ModelOutputKind.functionCall);
    expect(two.kind, ModelOutputKind.multipleCalls);
    expect(const RawModelOutput(text: 'Sure!').kind, ModelOutputKind.prose);
    expect(const RawModelOutput().kind, ModelOutputKind.empty);
    final p = a.adapt(two);
    expect(p.isMalformed, isTrue);
    expect(p.action, isNull); // no "first call wins"
    expect(p.malformedReason, contains('multiple_function_calls'));
  });

  test('multiple calls: category, rate, never executed', () async {
    const a = ModelOutputAdapter();
    final r = await Evaluator(
      model: _Out((_) {
        const raw = RawModelOutput(
          calls: [
            RawFunctionCall('change_theme', {'mode': 'dark'}),
            RawFunctionCall('change_theme', {'mode': 'dark'}),
          ],
        );
        return (a.adapt(raw), raw.kind);
      }),
    ).run(EvalDataset('t', 1, [c('a', 'english', theme('dark'))]));
    expect(r.cases.single.failureCategory!.wireName, 'multiple_function_calls');
    expect(r.cases.single.executed, isFalse);
    expect(r.metrics()['multipleFunctionCallRatePct'], 100);
    expect(r.metrics()['invalidOutputRatePct'], 100);
  });

  test(
    'prose: category, rate, strict metric; refusal-by-prose keeps Phase 2 scoring',
    () async {
      const a = ModelOutputAdapter();
      final r =
          await Evaluator(
            model: _Out((_) {
              const raw = RawModelOutput(text: 'Sure, I can help.');
              return (a.adapt(raw), raw.kind);
            }),
          ).run(
            EvalDataset('t', 1, [
              c('want-call', 'msa_arabic', theme('dark')),
              c('refuse', 'english', refusal),
            ]),
          );
      expect(r.cases[0].failureCategory!.wireName, 'prose_output');
      expect(r.cases[0].executed, isFalse);
      expect(
        r.cases[1].fullPredictionCorrect,
        isTrue,
      ); // same scoring as Phase 2
      final m = r.metrics();
      expect(m['proseOutputRatePct'], 100);
      expect(m['fullPredictionAccuracyPct'], 50);
      expect(m['fullPredictionAccuracyProseAsInvalidPct'], 0);
    },
  );

  test('navigate(profile) collapse is tagged only when it is wrong', () async {
    final r =
        await Evaluator(
          model: _Out(
            (_) => (
              const ActionPrediction(
                status: 'success',
                action: 'navigate',
                parameters: {'destination': 'profile'},
              ),
              ModelOutputKind.functionCall,
            ),
          ),
        ).run(
          EvalDataset('t', 1, [
            c('theme', 'english', theme('dark')),
            c('refuse', 'english', refusal),
            EvalCase(
              id: 'real',
              language: 'english',
              input: 'real',
              expected: const ExpectedResult(
                status: 'success',
                action: 'navigate',
                parameters: {'destination': 'profile'},
                acceptableStatuses: ['success'],
              ),
            ),
          ]),
        );
    expect(
      [
        for (final x in r.cases)
          x.failureTags.contains('navigate_profile_collapse'),
      ],
      [true, true, false],
    );
    expect(r.metrics()['navigateProfileCollapseCases'], 2);
  });

  group('recovery datasets', () {
    EvalDataset load(String n) => EvalDataset.parse(
      File('evaluation/datasets/$n.json').readAsStringSync(),
    );
    final frozen = load('phase_2_v1');
    final dev = load('phase_2_recovery_v1');
    final held = load('phase_2_recovery_heldout_v1');
    Set<String> inputs(EvalDataset d) => {
      for (final x in d.cases) x.input.trim().toLowerCase(),
    };

    test('sizes, languages and unique ids', () {
      expect(dev.cases.length, 48);
      expect(held.cases.length, 64);
      for (final d in [dev, held]) {
        expect({for (final x in d.cases) x.id}.length, d.cases.length);
        for (final l in ['english', 'msa_arabic', 'egyptian_arabic', 'mixed']) {
          expect(
            d.cases.where((x) => x.language == l).length,
            d.cases.length ~/ 4,
          );
        }
      }
    });

    test('no input appears in more than one of frozen / dev / held-out', () {
      expect(inputs(dev).intersection(inputs(frozen)), isEmpty);
      expect(inputs(held).intersection(inputs(frozen)), isEmpty);
      expect(inputs(held).intersection(inputs(dev)), isEmpty);
    });

    test(
      'frozen Phase 2 dataset and result are byte-identical to the baseline',
      () {
        expect(
          fnv(File('evaluation/datasets/phase_2_v1.json').readAsBytesSync()),
          BigInt.parse('55466734a476b9ed', radix: 16),
        );
        expect(
          fnv(File('evaluation/results/phase_2_v1.json').readAsBytesSync()),
          BigInt.parse('277e82a8c3edfcec', radix: 16),
        );
      },
    );
  });

  group('round 2 prompts and held-out v2', () {
    EvalDataset load(String n) => EvalDataset.parse(
      File('evaluation/datasets/$n.json').readAsStringSync(),
    );
    String n(String s) =>
        s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final names = [for (final t in phase2ToolSpecs) t.name];
    const earlier = [
      'phase_2_v1',
      'phase_2_recovery_v1',
      'phase_2_recovery_heldout_v1',
    ];

    test(
      'v2 adds the abstention rule and no examples; v3 adds the negative examples',
      () {
        final v1 = promptRecoveryV1.build(names);
        final v2 = promptRecoveryV2.build(names);
        final v3 = promptRecoveryV3.build(names);
        expect(v2, startsWith(v1));
        expect(v2, contains('Never guess a parameter value'));
        expect(v2, isNot(contains('must NOT call')));
        expect(v3, startsWith(v2));
        for (final e in recoveryNegativeExamples) {
          expect(v3, contains('"$e"'));
        }
        for (final other in [
          'change_language',
          'toggle_notifications',
          'search',
        ]) {
          expect(v3, isNot(contains(other)));
        }
      },
    );

    test(
      'held-out v2 has 64 unique cases, 16 per language, 25% of each kind',
      () {
        final h = load('phase_2_recovery_heldout_v2');
        expect(h.cases.length, 64);
        expect({for (final x in h.cases) n(x.input)}.length, 64);
        for (final l in ['english', 'msa_arabic', 'egyptian_arabic', 'mixed']) {
          expect(h.cases.where((x) => x.language == l).length, 16);
        }
        expect(
          h.cases.where((x) => x.expected.action == 'change_theme').length,
          16,
        );
        expect(
          h.cases.where((x) => x.expected.action == 'navigate').length,
          16,
        );
        expect(
          h.cases.where((x) => x.expected.status == 'unsupported').length,
          16,
        );
        expect(
          h.cases
              .where((x) => x.expected.status == 'clarification_required')
              .length,
          16,
        );
      },
    );

    test(
      'no overlap between held-out v2, earlier datasets, or any prompt example',
      () {
        final h = {
          for (final x in load('phase_2_recovery_heldout_v2').cases) n(x.input),
        };
        final examples = {
          for (final e in recoveryNegativeExamples) n(e),
          for (final e in assistantFewShotExamples) n(e.$1),
        };
        expect(h.intersection(examples), isEmpty);
        for (final d in earlier) {
          final inputs = {for (final x in load(d).cases) n(x.input)};
          expect(h.intersection(inputs), isEmpty, reason: d);
          expect(
            inputs.intersection({
              for (final e in recoveryNegativeExamples) n(e),
            }),
            isEmpty,
            reason: 'negative examples vs $d',
          );
        }
      },
    );
  });

  test(
    'Qwen prompt lists only the tools actually exposed (no hard-coded actions)',
    () {
      final names = [for (final t in phase2ToolSpecs) t.name];
      final text = promptRecoveryV1.build(names);
      expect(text, contains('- change_theme'));
      expect(text, contains('- navigate'));
      for (final other in [
        'change_language',
        'toggle_notifications',
        'search',
      ]) {
        expect(text, isNot(contains(other)));
      }
      expect(
        promptRecoveryV1.build(['navigate']),
        isNot(contains('change_theme')),
      );
    },
  );
}

void modelConfigTests() {
  test(
    'every catalog model exposes only the registered tools and a versioned prompt',
    () {
      for (final cfg in ModelCatalog.all) {
        final m = FlutterGemmaAssistantModel(cfg);
        final info = m.runtimeInfo;
        expect(info['tools'], ['change_theme', 'navigate'], reason: cfg.id);
        expect(info['promptVersion'], isNotEmpty);
        expect(info['modelId'], cfg.id);
      }
      expect(ModelCatalog.gemma4E2b.prompt.id, 'recovery_prompt_v1');
      expect(
        ModelCatalog.functionGemma270m.prompt.id,
        'functiongemma_prompt_v1',
      );
      expect(ModelCatalog.byId('gemma4e4b').approxSizeMb, greaterThan(3000));
      expect(() => ModelCatalog.byId('nope'), throwsArgumentError);
    },
  );

  test(
    'createLocalModel applies a prompt and a local file without touching the config',
    () {
      final m = createLocalModel(
        'gemma4',
        prompt: promptClarifyV4,
        modelFilePath: '/x/y.litertlm',
      );
      expect(
        (m as FlutterGemmaAssistantModel).config.prompt.id,
        'clarify_prompt_v4',
      );
      expect(m.config.modelFilePath, '/x/y.litertlm');
      expect(ModelCatalog.gemma4E2b.modelFilePath, isNull);
      expect(ModelCatalog.gemma4E2b.prompt.id, 'recovery_prompt_v1');
    },
  );
}
