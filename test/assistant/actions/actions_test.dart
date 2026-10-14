import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:assistant_poc/assistant/models/action_parameters.dart';
import 'package:assistant_poc/assistant/models/action_prediction.dart';
import 'package:assistant_poc/assistant/validation/action_validator.dart';
import 'package:assistant_poc/assistant/execution/action_executor.dart';
import 'package:assistant_poc/assistant/validation/validation_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

ActionPrediction ok(String action, Map<String, Object?> p) =>
    ActionPrediction.fromDecoded({
      'status': 'success',
      'action': action,
      'parameters': p,
    });

void main() {
  late RecordingEnvironment env;
  late ActionRegistry registry;
  late ActionValidator validator;
  late ActionExecutor executor;

  setUp(() {
    env = RecordingEnvironment();
    registry = ActionRegistry.standard();
    validator = ActionValidator(registry);
    executor = ActionExecutor(registry, env);
  });

  Future<void> run(ActionPrediction p) async {
    final v = validator.validate(p);
    expect(v, isA<ValidationAccepted>());
    final r = await executor.execute((v as ValidationAccepted).validated);
    expect(r.isExecuted, isTrue, reason: r.message);
  }

  test('registry contains exactly the five Phase 1 actions', () {
    expect(registry.names.toSet(), {
      'change_theme',
      'change_language',
      'navigate',
      'toggle_notifications',
      'search',
    });
    expect(registry.lookup('exit_app'), isNull);
  });

  for (final m in ThemeModeOption.values) {
    test('change_theme / ${m.name}', () async {
      await run(ok('change_theme', {'mode': m.name}));
      expect(env.themeMode, m);
    });
  }
  for (final l in AppLanguage.values) {
    test('change_language / ${l.name}', () async {
      await run(ok('change_language', {'language': l.name}));
      expect(env.language, l);
    });
  }
  for (final d in AppDestination.values) {
    test('navigate / ${d.name}', () async {
      await run(ok('navigate', {'destination': d.name}));
      expect(env.destination, d);
    });
  }
  for (final e in [true, false]) {
    test('toggle_notifications / $e', () async {
      await run(ok('toggle_notifications', {'enabled': e}));
      expect(env.notificationsEnabled, e);
    });
  }
  test('search / non-empty query (trimmed)', () async {
    await run(ok('search', {'query': '  medical equipment '}));
    expect(env.lastSearchQuery, 'medical equipment');
  });
}
