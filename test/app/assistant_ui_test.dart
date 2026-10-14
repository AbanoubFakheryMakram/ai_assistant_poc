import 'package:assistant_poc/app/app_state.dart';
import 'package:assistant_poc/app/assistant/assistant_controller.dart';
import 'package:assistant_poc/app/home_shell.dart';
import 'package:assistant_poc/app/model_host.dart';
import 'package:assistant_poc/app/theme.dart';
import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:assistant_poc/assistant/execution/action_executor.dart';
import 'package:assistant_poc/assistant/execution/assistant_pipeline.dart';
import 'package:assistant_poc/assistant/models/action_parameters.dart';
import 'package:assistant_poc/assistant/models/action_prediction.dart';
import 'package:assistant_poc/assistant/providers/assistant_model.dart';
import 'package:assistant_poc/assistant/providers/model_catalog.dart';
import 'package:assistant_poc/assistant/providers/model_output_adapter.dart';
import 'package:assistant_poc/assistant/validation/action_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for a local model ONLY to test the UI wiring. It speaks the same
/// raw-output vocabulary a real model does, then goes through the real adapter.
class _FakeModel implements LoadableAssistantModel {
  _FakeModel(this.reply);
  final RawModelOutput Function(String input) reply;
  @override
  String get modelName => 'fake';
  @override
  Map<String, Object?> get runtimeInfo => {};
  @override
  Future<ModelLoadReport> load({
    void Function(int percent)? onProgress,
  }) async => const ModelLoadReport(
    installDuration: Duration.zero,
    loadDuration: Duration(milliseconds: 5),
    downloadedFromNetwork: false,
  );
  @override
  Future<void> dispose() async {}
  @override
  Future<ActionPrediction> interpret(String input) async =>
      (await interpretWithTrace(input)).prediction;
  @override
  Future<ModelInterpretation> interpretWithTrace(String input) async {
    final raw = reply(input);
    return ModelInterpretation(
      prediction: const ModelOutputAdapter().adapt(raw),
      rawOutput: raw.describe(),
      latency: const Duration(milliseconds: 7),
      outputKind: raw.kind,
    );
  }
}

RawModelOutput call(String name, Map<String, Object?> args) =>
    RawModelOutput(calls: [RawFunctionCall(name, args)]);

void main() {
  late AppState state;
  late ModelHost host;

  Future<void> pumpApp(
    WidgetTester tester,
    RawModelOutput Function(String) reply,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    state = AppState();
    host = ModelHost(
      catalog: [ModelCatalog.gemma4E2b, ModelCatalog.gemma4E4b],
      loader: (_) => _FakeModel(reply),
    );
    final registry = ActionRegistry.phase2();
    final assistant = AssistantController(
      pipeline: AssistantPipeline(
        ActionValidator(registry),
        ActionExecutor(registry, state),
        registry: registry,
      ),
      host: host,
    );
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: state,
        builder: (_, _) => MaterialApp(
          theme: buildTheme(Brightness.light),
          home: HomeShell(state: state, host: host, assistant: assistant),
        ),
      ),
    );
  }

  Future<void> turnOn(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('load_model')));
    await tester.pumpAndSettle();
  }

  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('assistant_input')), text);
    await tester.tap(find.byKey(const Key('assistant_send')));
    await tester.pumpAndSettle();
  }

  testWidgets('assistant is off until the model is turned on', (tester) async {
    await pumpApp(tester, (_) => const RawModelOutput());
    expect(find.byKey(const Key('model_banner')), findsOneWidget);
    expect(find.textContaining('Gemma 4 E2B'), findsWidgets);
    final input = tester.widget<TextField>(
      find.byKey(const Key('assistant_input')),
    );
    expect(input.enabled, isFalse);
    await turnOn(tester);
    expect(find.byKey(const Key('model_banner')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant_input')))
          .enabled,
      isTrue,
    );
  });

  testWidgets('a clear request is validated, executed and explained', (
    tester,
  ) async {
    await pumpApp(tester, (_) => call('change_theme', {'mode': 'dark'}));
    await turnOn(tester);
    await say(tester, 'خلي التطبيق دارك');
    expect(state.themeMode, ThemeModeOption.dark);
    expect(find.text('Theme set to dark'), findsOneWidget);
    expect(find.byKey(const Key('state_theme')), findsOneWidget);
    expect(find.text('Dark'), findsWidgets);
    await tester.tap(find.byKey(const Key('toggle_details')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('turn_details')), findsOneWidget);
    expect(find.textContaining('change_theme'), findsWidgets);
    expect(find.textContaining('EXECUTED'), findsOneWidget);
  });

  testWidgets(
    'a vague request asks the user, executes nothing, then the user decides',
    (tester) async {
      await pumpApp(
        tester,
        (_) => call('ask_user', {'target': 'change_theme.mode'}),
      );
      await turnOn(tester);
      await say(tester, 'Change the theme');
      expect(find.text('Which theme do you want?'), findsOneWidget);
      expect(
        state.themeMode,
        ThemeModeOption.light,
        reason: 'nothing runs before the user answers',
      );
      // Options are the application's, labelled for the user.
      for (final k in ['choice_light', 'choice_dark', 'choice_system']) {
        expect(find.byKey(Key(k)), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('choice_dark')));
      await tester.pumpAndSettle();
      expect(state.themeMode, ThemeModeOption.dark);
      expect(find.text('Theme set to dark'), findsOneWidget);
    },
  );

  testWidgets('a vague page request offers exactly the registered pages', (
    tester,
  ) async {
    await pumpApp(
      tester,
      (_) => call('ask_user', {'target': 'navigate.destination'}),
    );
    await turnOn(tester);
    await say(tester, 'Open a page');
    expect(find.text('Which page do you want to open?'), findsOneWidget);
    expect(find.byKey(const Key('choice_home')), findsOneWidget);
    expect(find.byKey(const Key('choice_profile')), findsOneWidget);
    expect(find.byKey(const Key('choice_settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('choice_settings')));
    await tester.pumpAndSettle();
    expect(state.destination, AppDestination.settings);
  });

  testWidgets('"None of these" leaves everything unchanged', (tester) async {
    await pumpApp(
      tester,
      (_) => call('ask_user', {'target': 'change_theme.mode'}),
    );
    await turnOn(tester);
    await say(tester, 'Change the theme');
    await tester.tap(find.byKey(const Key('choice_none')));
    await tester.pumpAndSettle();
    expect(state.themeMode, ThemeModeOption.light);
    expect(find.text('Okay, nothing changed.'), findsOneWidget);
  });

  testWidgets('a model asking about something not allowed shows no options', (
    tester,
  ) async {
    await pumpApp(
      tester,
      (_) => call('ask_user', {'target': 'delete_account.confirm'}),
    );
    await turnOn(tester);
    await say(tester, 'anything');
    expect(find.byKey(const Key('choice_none')), findsNothing);
    expect(find.textContaining("can't do that"), findsOneWidget);
  });

  testWidgets('an unsupported request is declined and nothing runs', (
    tester,
  ) async {
    await pumpApp(
      tester,
      (_) => const RawModelOutput(text: 'I cannot send emails.'),
    );
    await turnOn(tester);
    await say(tester, 'ابعتلي إيميل');
    expect(find.textContaining("can't do that"), findsOneWidget);
    expect(state.themeMode, ThemeModeOption.light);
    expect(state.destination, AppDestination.home);
  });

  testWidgets(
    'an invalid proposal (outside the registry) is rejected, not executed',
    (tester) async {
      await pumpApp(tester, (_) => call('change_language', {'language': 'ar'}));
      await turnOn(tester);
      await say(tester, 'speak arabic');
      expect(state.language, AppLanguage.en);
      expect(find.textContaining('nothing was changed'), findsOneWidget);
    },
  );

  testWidgets('an out-of-enum value is rejected by the validator', (
    tester,
  ) async {
    await pumpApp(tester, (_) => call('navigate', {'destination': 'facebook'}));
    await turnOn(tester);
    await say(tester, 'open facebook');
    expect(state.destination, AppDestination.home);
    expect(find.textContaining('nothing was changed'), findsOneWidget);
  });

  testWidgets('settings page: manual controls, language flips the whole UI', (
    tester,
  ) async {
    await pumpApp(tester, (_) => const RawModelOutput());
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('seg_language')),
        matching: find.text('العربية'),
      ),
    );
    await tester.pumpAndSettle();
    expect(state.language, AppLanguage.ar);
    expect(find.text('الإعدادات'), findsWidgets);
    await tester.tap(find.byKey(const Key('switch_notifications')));
    await tester.pumpAndSettle();
    expect(state.notificationsEnabled, isFalse);
  });

  testWidgets('developer tools: raw JSON goes through validation (Phase 1 path)', (
    tester,
  ) async {
    await pumpApp(tester, (_) => const RawModelOutput());
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_developer')));
    await tester.pumpAndSettle();

    Future<void> submit(String json) async {
      await tester.enterText(find.byKey(const Key('prediction_input')), json);
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
    }

    await submit(
      '{"status":"success","action":"toggle_notifications","parameters":{"enabled":false}}',
    );
    expect(state.notificationsEnabled, isFalse);
    expect(find.text('→ EXECUTED (Notifications disabled)'), findsOneWidget);

    await submit(
      '{"status":"success","action":"change_theme","parameters":{"mode":"blue"}}',
    );
    expect(state.themeMode, ThemeModeOption.light);
    expect(find.text('→ NOT EXECUTED'), findsOneWidget);
    expect(find.text('→ REJECTED'), findsOneWidget);
  });
}
