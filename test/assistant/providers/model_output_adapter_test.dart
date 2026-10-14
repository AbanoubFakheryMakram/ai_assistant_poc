import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:assistant_poc/assistant/execution/action_executor.dart';
import 'package:assistant_poc/assistant/execution/assistant_pipeline.dart';
import 'package:assistant_poc/assistant/models/action_parameters.dart';
import 'package:assistant_poc/assistant/providers/model_output_adapter.dart';
import 'package:assistant_poc/assistant/validation/action_validator.dart';
import 'package:assistant_poc/assistant/validation/validation_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const adapter = ModelOutputAdapter();
  late RecordingEnvironment env;
  late AssistantPipeline pipeline;

  setUp(() {
    final registry = ActionRegistry.phase2();
    env = RecordingEnvironment();
    pipeline = AssistantPipeline(
      ActionValidator(registry),
      ActionExecutor(registry, env),
    );
  });

  test('function call maps to a success ActionPrediction', () {
    final p = adapter.adapt(
      const RawModelOutput(
        calls: [
          RawFunctionCall('change_theme', {'mode': 'dark'}),
        ],
      ),
    );
    expect(p.status, 'success');
    expect(p.action, 'change_theme');
    expect(p.parameters, {'mode': 'dark'});
  });

  test('no function call maps to unsupported (never success)', () {
    final p = adapter.adapt(const RawModelOutput(text: 'Sure, I can help!'));
    expect(p.status, 'unsupported');
    expect(p.action, isNull);
  });

  test('several calls are malformed', () {
    final p = adapter.adapt(
      const RawModelOutput(
        calls: [
          RawFunctionCall('change_theme', {'mode': 'dark'}),
          RawFunctionCall('navigate', {'destination': 'home'}),
        ],
      ),
    );
    expect(p.isMalformed, isTrue);
  });

  test('call without a name is malformed', () {
    expect(
      adapter
          .adapt(const RawModelOutput(calls: [RawFunctionCall(' ', {})]))
          .isMalformed,
      isTrue,
    );
  });

  test('adapter does not repair values (passed through verbatim)', () {
    final p = adapter.adapt(
      const RawModelOutput(
        calls: [
          RawFunctionCall('navigate', {'destination': 'Profile '}),
        ],
      ),
    );
    expect(p.parameters, {'destination': 'Profile '});
  });

  group('adapted output is rejected unless valid, and never executes', () {
    Future<void> rejects(RawModelOutput out) async {
      final o = await pipeline.process(adapter.adapt(out));
      expect(o.validation, isA<ValidationRejected>());
      expect(o.execution, isNull);
      expect(env.calls, isEmpty);
    }

    test(
      'unsupported function (real Phase 1 action, not exposed in Phase 2)',
      () => rejects(
        const RawModelOutput(
          calls: [
            RawFunctionCall('change_language', {'language': 'ar'}),
          ],
        ),
      ),
    );
    test(
      'invented function',
      () => rejects(
        const RawModelOutput(calls: [RawFunctionCall('delete_account', {})]),
      ),
    );
    test(
      'invented destination',
      () => rejects(
        const RawModelOutput(
          calls: [
            RawFunctionCall('navigate', {'destination': 'facebook'}),
          ],
        ),
      ),
    );
    test(
      'invented theme',
      () => rejects(
        const RawModelOutput(
          calls: [
            RawFunctionCall('change_theme', {'mode': 'blue'}),
          ],
        ),
      ),
    );
    test(
      'missing argument',
      () => rejects(
        const RawModelOutput(calls: [RawFunctionCall('change_theme', {})]),
      ),
    );
    test(
      'extra argument',
      () => rejects(
        const RawModelOutput(
          calls: [
            RawFunctionCall('change_theme', {'mode': 'dark', 'x': 1}),
          ],
        ),
      ),
    );
    test(
      'plain text',
      () => rejects(const RawModelOutput(text: 'dark mode on')),
    );
    test(
      'multiple calls',
      () => rejects(
        const RawModelOutput(
          calls: [
            RawFunctionCall('change_theme', {'mode': 'dark'}),
            RawFunctionCall('change_theme', {'mode': 'light'}),
          ],
        ),
      ),
    );
  });

  test('valid adapted call executes through validator + executor', () async {
    final o = await pipeline.process(
      adapter.adapt(
        const RawModelOutput(
          calls: [
            RawFunctionCall('navigate', {'destination': 'profile'}),
          ],
        ),
      ),
    );
    expect(o.execution!.isExecuted, isTrue);
    expect(env.destination, AppDestination.profile);
  });
}
