import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:assistant_poc/assistant/execution/assistant_pipeline.dart';
import 'package:assistant_poc/assistant/models/action_parameters.dart';
import 'package:assistant_poc/assistant/providers/model_output_adapter.dart';
import 'package:assistant_poc/assistant/providers/model_prompt.dart';
import 'package:assistant_poc/assistant/validation/action_validator.dart';
import 'package:assistant_poc/assistant/validation/validation_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const adapter = ModelOutputAdapter();
  late ActionRegistry registry;
  late RecordingEnvironment env;
  late SpyExecutor executor;
  late AssistantPipeline pipeline;

  setUp(() {
    registry = ActionRegistry.phase2();
    env = RecordingEnvironment();
    executor = SpyExecutor(registry, env);
    pipeline = AssistantPipeline(
      ActionValidator(registry),
      executor,
      registry: registry,
    );
  });

  RawModelOutput ask(Object? target) => RawModelOutput(
    calls: [
      RawFunctionCall('ask_user', {'target': target}),
    ],
  );

  group('tool definitions come from the registry', () {
    test(
      'phase 2 registry offers two actions and, only when asked, ask_user',
      () {
        expect(
          [for (final t in registry.toolSpecs()) t.name],
          ['change_theme', 'navigate'],
        );
        final withAsk = registry.toolSpecs(allowClarification: true);
        expect(
          [for (final t in withAsk) t.name],
          ['change_theme', 'navigate', 'ask_user'],
        );
        final targets =
            (withAsk.last.parameters['properties']! as Map)['target'] as Map;
        expect(targets['enum'], ['change_theme.mode', 'navigate.destination']);
      },
    );

    test('actions not in the registry never appear in tool definitions', () {
      final all = [
        for (final t in registry.toolSpecs(allowClarification: true)) t.name,
      ];
      for (final other in [
        'change_language',
        'toggle_notifications',
        'search',
      ]) {
        expect(all, isNot(contains(other)));
      }
      expect(ActionRegistry.standard().toolSpecs().length, 5);
    });

    test('tool schema enums equal the enums the validator uses', () {
      final theme = registry.toolSpecs().first.parameters['properties']! as Map;
      expect((theme['mode'] as Map)['enum'], [
        for (final m in ThemeModeOption.values) m.name,
      ]);
    });
  });

  group('ask_user is a question, never an action', () {
    test('adapter maps it to clarification_required with the raw target', () {
      final p = adapter.adapt(ask('change_theme.mode'));
      expect(p.status, 'clarification_required');
      expect(p.action, isNull);
      expect((p.parameters! as Map)['target'], 'change_theme.mode');
    });

    test(
      'pipeline returns the registry options and executes nothing',
      () async {
        final o = await pipeline.process(
          adapter.adapt(ask('change_theme.mode')),
        );
        expect(o.validation, isA<ValidationRejected>());
        expect(o.execution, isNull);
        expect(o.clarification!.target, 'change_theme.mode');
        expect(o.clarification!.options, ['light', 'dark', 'system']);
        expect(executor.executeCalls, 0);
        expect(env.calls, isEmpty);
      },
    );

    test('navigate offer lists exactly the registered destinations', () async {
      final o = await pipeline.process(
        adapter.adapt(ask('navigate.destination')),
      );
      expect(o.clarification!.options, ['home', 'profile', 'settings']);
    });

    for (final bad in <Object?>[
      'change_language.language', // real action, not in this registry
      'navigate.route',
      'change_theme',
      '',
      null,
      42,
      'delete_everything.now',
    ]) {
      test('invalid target $bad gives no offer and executes nothing', () async {
        final o = await pipeline.process(adapter.adapt(ask(bad)));
        expect(o.clarification, isNull);
        expect(o.execution, isNull);
        expect(executor.executeCalls, 0);
        expect(env.calls, isEmpty);
      });
    }

    test('the model cannot add options or pick a value', () async {
      final raw = const RawModelOutput(
        calls: [
          RawFunctionCall('ask_user', {
            'target': 'change_theme.mode',
            'options': ['blue'],
            'choice': 'dark',
          }),
        ],
      );
      final o = await pipeline.process(adapter.adapt(raw));
      expect(o.clarification!.options, ['light', 'dark', 'system']);
      expect(env.calls, isEmpty);
    });
  });

  group('the user decides', () {
    test('a chosen value goes through validation and executes once', () async {
      final offer = (await pipeline.process(
        adapter.adapt(ask('change_theme.mode')),
      )).clarification!;
      expect(env.calls, isEmpty);
      final done = await pipeline.resolveClarification(offer, 'dark');
      expect(done.execution!.isExecuted, isTrue);
      expect(env.themeMode, ThemeModeOption.dark);
      expect(executor.executeCalls, 1);
    });

    test('navigate choice executes through the same path', () async {
      final offer = (await pipeline.process(
        adapter.adapt(ask('navigate.destination')),
      )).clarification!;
      await pipeline.resolveClarification(offer, 'settings');
      expect(env.destination, AppDestination.settings);
    });

    test(
      'a value outside the offer is rejected by the validator, not executed',
      () async {
        final offer = (await pipeline.process(
          adapter.adapt(ask('change_theme.mode')),
        )).clarification!;
        final done = await pipeline.resolveClarification(offer, 'blue');
        expect(done.validation, isA<ValidationRejected>());
        expect(done.execution, isNull);
        expect(env.calls, isEmpty);
      },
    );
  });

  group('prompt v4', () {
    test(
      'mentions ask_user only when it is exposed, and lists only registered actions',
      () {
        final withAsk = promptClarifyV4.build([
          'change_theme',
          'navigate',
          'ask_user',
        ]);
        expect(withAsk, contains('call ask_user'));
        expect(withAsk, contains('- change_theme'));
        expect(withAsk, isNot(contains('- ask_user')));
        final without = promptClarifyV4.build(['change_theme', 'navigate']);
        expect(without, isNot(contains('ask_user')));
        expect(withAsk, isNot(contains('change_language')));
      },
    );
  });
}
