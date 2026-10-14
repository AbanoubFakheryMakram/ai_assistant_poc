import 'dart:convert';
import 'dart:io';

import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:assistant_poc/assistant/actions/change_theme_action.dart';
import 'package:assistant_poc/assistant/execution/action_executor.dart';
import 'package:assistant_poc/assistant/execution/assistant_pipeline.dart';
import 'package:assistant_poc/assistant/models/action_parameters.dart';
import 'package:assistant_poc/assistant/models/action_prediction.dart';
import 'package:assistant_poc/assistant/providers/assistant_model.dart';
import 'package:assistant_poc/assistant/validation/action_validator.dart';
import 'package:assistant_poc/assistant/validation/validation_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late RecordingEnvironment env;
  late SpyExecutor executor;
  late AssistantPipeline pipeline;

  setUp(() {
    final registry = ActionRegistry.standard();
    env = RecordingEnvironment();
    executor = SpyExecutor(registry, env);
    pipeline = AssistantPipeline(ActionValidator(registry), executor);
  });

  void expectNeverExecuted(PipelineOutcome o) {
    expect(o.validation, isA<ValidationRejected>());
    expect(o.execution, isNull);
    expect(executor.executeCalls, 0, reason: 'executor must not be reached');
    expect(env.calls, isEmpty, reason: 'app must not be touched');
  }

  group('rejected predictions never reach the executor', () {
    final bad = <String, String>{
      'unknown action': '{"status":"success","action":"nope","parameters":{}}',
      'missing params':
          '{"status":"success","action":"change_theme","parameters":{}}',
      'invalid enum':
          '{"status":"success","action":"change_theme","parameters":{"mode":"blue"}}',
      'arbitrary route':
          '{"status":"success","action":"navigate","parameters":{"destination":"/admin"}}',
      'wrong bool type':
          '{"status":"success","action":"toggle_notifications","parameters":{"enabled":"yes"}}',
      'empty query':
          '{"status":"success","action":"search","parameters":{"query":""}}',
      'extra params':
          '{"status":"success","action":"change_theme","parameters":{"mode":"dark","deleteEverything":true}}',
      'null params':
          '{"status":"success","action":"change_theme","parameters":null}',
      'malformed json': '{"status":',
      'clarification_required':
          '{"status":"clarification_required","action":null,"parameters":{}}',
      'unsupported': '{"status":"unsupported","action":null,"parameters":{}}',
      'non-success with valid action':
          '{"status":"unsupported","action":"change_theme","parameters":{"mode":"dark"}}',
    };
    for (final e in bad.entries) {
      test(e.key, () async {
        expectNeverExecuted(
          await pipeline.process(ActionPrediction.fromJsonString(e.value)),
        );
      });
    }
  });

  test('valid prediction reaches executor exactly once', () async {
    final o = await pipeline.process(
      ActionPrediction.fromJsonString(
        '{"status":"success","action":"change_theme","parameters":{"mode":"dark"}}',
      ),
    );
    expect(o.execution!.isExecuted, isTrue);
    expect(executor.executeCalls, 1);
    expect(env.themeMode, ThemeModeOption.dark);
  });

  test('executor refuses an action that is not in its registry', () async {
    // A validated action built against a registry that the executor does not use.
    final other = ActionRegistry([ChangeThemeAction()]);
    final v = ActionValidator(other).validate(
      ActionPrediction.fromDecoded({
        'status': 'success',
        'action': 'change_theme',
        'parameters': {'mode': 'dark'},
      }),
    );
    final foreign = (v as ValidationAccepted).validated;
    final result = await ActionExecutor(
      ActionRegistry.standard(),
      env,
    ).execute(foreign);
    expect(result.isExecuted, isFalse);
    expect(env.calls, isEmpty);
  });

  test(
    'pipeline consumes any AssistantModel (mock) without caring about source',
    () async {
      final model = MockAssistantModel({
        'dark please': const ActionPrediction(
          status: 'success',
          action: 'change_theme',
          parameters: {'mode': 'dark'},
        ),
      });
      final executed = await pipeline.process(
        await model.interpret('dark please'),
      );
      expect(executed.execution!.isExecuted, isTrue);
      expectLater(env.themeMode, ThemeModeOption.dark);

      final env2 = env.calls.length;
      final unknown = await pipeline.process(
        await model.interpret('gibberish'),
      );
      expect(unknown.execution, isNull);
      expect(env.calls.length, env2);
    },
  );

  group('evaluation/phase_1_commands.json', () {
    final data =
        jsonDecode(File('evaluation/phase_1_commands.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final c in (data['cases'] as List).cast<Map<String, dynamic>>()) {
      test('${c['category']}: ${c['id']}', () async {
        final prediction = c.containsKey('rawPayload')
            ? ActionPrediction.fromJsonString(c['rawPayload'] as String)
            : ActionPrediction.fromDecoded(c['payload']);
        final o = await pipeline.process(prediction);
        if (c['expect'] == 'executed') {
          expect(o.execution?.isExecuted, isTrue);
          final st = c['expectedState'] as Map<String, dynamic>;
          expect({
            'themeMode': env.themeMode?.name,
            'language': env.language?.name,
            'destination': env.destination?.name,
            'notificationsEnabled': env.notificationsEnabled,
            'lastSearchQuery': env.lastSearchQuery,
          }, containsPair(st.keys.first, st.values.first));
        } else {
          expectNeverExecuted(o);
          expect(
            (o.validation as ValidationRejected).reason.name,
            c['expectedReason'],
          );
        }
      });
    }
  });
}
