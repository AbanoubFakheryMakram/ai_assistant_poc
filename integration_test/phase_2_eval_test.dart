// Phase 2 on-device evaluation. Runs the REAL FunctionGemma 270M model (no
// mocks) through: model -> adapter -> ActionPrediction -> validator ->
// registry -> executor.
//
//   flutter test integration_test/phase_2_eval_test.dart -d <ios-simulator-or-device> \
//     --dart-define=DEVICE_NAME="iPhone 17 Pro Max" --dart-define=DEVICE_KIND=simulator \\
//     [--dart-define=MODEL=functiongemma|qwen3|gemma4|gemma4e4b] \\
//     [--dart-define=DATASETS=phase_2_v1,phase_2_recovery_v1] \\
//     [--dart-define=MODEL_FILE=/abs/path/to/model.litertlm]
//
// The device shows a live progress screen (stage, current command, model
// output, running accuracy, safety counter). The result JSON is printed in `EVAL_CHUNK <n> <text>` lines; use
// tool/extract_eval_results.py to turn the log into
// evaluation/results/phase_2_v1.json.
import 'dart:convert';
import 'dart:io';

import 'package:assistant_poc/app/app_state.dart';
import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:assistant_poc/assistant/evaluation/eval_dataset.dart';
import 'package:assistant_poc/assistant/evaluation/evaluator.dart';
import 'package:assistant_poc/assistant/execution/action_executor.dart';
import 'package:assistant_poc/assistant/execution/assistant_pipeline.dart';
import 'package:assistant_poc/assistant/models/action_parameters.dart';
import 'package:assistant_poc/assistant/providers/assistant_model.dart';
import 'package:assistant_poc/assistant/providers/local_model_factory.dart';
import 'package:assistant_poc/assistant/providers/model_catalog.dart';
import 'package:assistant_poc/assistant/providers/model_prompt.dart';
import 'package:assistant_poc/assistant/validation/action_validator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/eval_progress.dart';
import 'support/eval_progress_screen.dart';

void emit(String name, Map<String, Object?> json) {
  final text = jsonEncode(json);
  const size = 700;
  var i = 0;
  for (var o = 0; o < text.length; o += size, i++) {
    final end = o + size > text.length ? text.length : o + size;
    // ignore: avoid_print
    print(
      'EVAL_CHUNK $name $i ${base64.encode(utf8.encode(text.substring(o, end)))}',
    );
  }
  // ignore: avoid_print
  print('EVAL_END $name $i');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Render continuously so the progress screen animates during long native calls.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // By default the live test binding ignores touches from the device, which
  // would make the progress screen impossible to scroll.
  binding.shouldPropagateDevicePointerEvents = true;

  testWidgets('Phase 2: on-device evaluation', (tester) async {
    const modelId = String.fromEnvironment(
      'MODEL',
      defaultValue: 'functiongemma',
    );
    const modelFile = String.fromEnvironment('MODEL_FILE');
    const datasets = String.fromEnvironment(
      'DATASETS',
      defaultValue: 'phase_2_v1',
    );
    const promptId = String.fromEnvironment('PROMPT');
    // Tools come from the registry. Offer the "ask the user" function only when
    // the prompt describes it.
    final prompt = promptId.isEmpty
        ? ModelCatalog.byId(modelId).prompt
        : promptVersionById(promptId);
    final clarify = prompt.id == promptClarifyV4.id;
    final registry = ActionRegistry.phase2();
    final LoadableAssistantModel model = createLocalModel(
      modelId,
      prompt: prompt,
      modelFilePath: modelFile.isEmpty ? null : modelFile,
      toolSpecs: registry.toolSpecs(allowClarification: clarify),
    );
    const holdSeconds = int.fromEnvironment('HOLD_SECONDS', defaultValue: 12);
    final live = EvalProgress(
      modelName: ModelCatalog.byId(modelId).displayName,
      promptId: prompt.id,
      device: const String.fromEnvironment(
        'DEVICE_NAME',
        defaultValue: 'device',
      ),
    );
    // Replace the harness's blank "Test starting..." as early as possible.
    await tester.pumpWidget(EvalProgressApp(progress: live));
    live.update(() {
      live.stage = EvalStage.downloading;
      live.message =
          ModelCatalog.byId(modelId).modelFilePath == null && modelFile.isEmpty
          ? 'Getting the model (about ${ModelCatalog.byId(modelId).approxSizeMb} MB)'
          : 'Using the model file already on this computer';
    });

    var lastPct = -10;
    final ModelLoadReport load;
    try {
      load = await model.load(
        onProgress: (p) {
          live.update(() => live.downloadPercent = p);
          if (p - lastPct >= 10) {
            lastPct = p;
            // ignore: avoid_print
            print('download: $p%');
          }
        },
      );
    } catch (e) {
      live.update(() {
        live.stage = EvalStage.failed;
        live.message = 'Could not load the model';
        live.error = '$e';
      });
      await Future<void>.delayed(const Duration(seconds: holdSeconds));
      // Surface the native engine log, which flutter_gemma does not print.
      final log = File('${Directory.systemTemp.path}/litertlm_native.log');
      // ignore: avoid_print
      print(
        'LOAD FAILED: $e\nNATIVE LOG:\n'
        '${log.existsSync() ? log.readAsStringSync() : '(none)'}',
      );
      rethrow;
    }
    // ignore: avoid_print
    print(
      'model loaded: install=${load.installDuration.inMilliseconds}ms '
      'load=${load.loadDuration.inMilliseconds}ms '
      'downloaded=${load.downloadedFromNetwork}',
    );

    final device = <String, Object?>{
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      // Passed on the command line: --dart-define=DEVICE_NAME=... --dart-define=DEVICE_KIND=simulator|physical
      'deviceName': const String.fromEnvironment(
        'DEVICE_NAME',
        defaultValue: 'unknown',
      ),
      'deviceKind': const String.fromEnvironment(
        'DEVICE_KIND',
        defaultValue: 'unknown',
      ),
      'processors': Platform.numberOfProcessors,
    };
    final modelLoad = <String, Object?>{
      'installMs': load.installDuration.inMilliseconds,
      'loadMs': load.loadDuration.inMilliseconds,
      'downloadedFromNetworkThisRun': load.downloadedFromNetwork,
    };

    live.update(() {
      live.stage = EvalStage.sanity;
      live.loadMs = load.loadDuration.inMilliseconds;
      live.message =
          'Model ready (loaded in ${(load.loadDuration.inMilliseconds / 1000).toStringAsFixed(1)} s)';
    });

    // 1) Integration sanity: real model, real pipeline, real app state.
    final state = AppState();
    final pipeline = AssistantPipeline(
      ActionValidator(registry),
      ActionExecutor(registry, state),
      registry: registry,
    );
    final sanity = <Map<String, Object?>>[];
    for (final input in [
      'Turn on dark mode',
      'خلي التطبيق دارك',
      'يا عم خلّي التطبيق دارك',
      'خلي الـtheme dark',
      'Open my profile',
      'افتح البروفايل',
      'روح على settings',
    ]) {
      final before = (state.themeMode, state.destination);
      live.update(() => live.nowInput = input);
      final i = await model.interpretWithTrace(input);
      final o = await pipeline.process(i.prediction);
      final executed = o.execution?.isExecuted ?? false;
      // Invariant: nothing executes unless validation accepted it.
      expect(executed, o.execution != null);
      sanity.add({
        'input': input,
        'raw': i.rawOutput,
        'action': i.prediction.action,
        'parameters': i.prediction.parameters,
        'validation': o.validation.runtimeType.toString(),
        'executed': executed,
        'themeBefore': before.$1.name,
        'themeAfter': state.themeMode.name,
        'pageAfter': state.destination.name,
        'latencyMs': i.latency.inMilliseconds,
      });
      live.update(() {
        live.sanity.add(
          LiveCase(
            input: input,
            output: i.rawOutput,
            correct: true,
            executed: executed,
            latencyMs: i.latency.inMilliseconds,
            note: '',
          ),
        );
        live.nowInput = null;
      });
      state.themeMode = ThemeModeOption.light;
      state.destination = AppDestination.home;
    }
    emit('sanity', {'sanity': sanity});
    // ignore: avoid_print
    print('sanity done');

    // 2) Dataset evaluations (same model instance, loaded once).
    var uncontrolled = 0, invalidExecuted = 0;
    final loaded = <(String, EvalDataset)>[];
    for (final name in datasets.split(',')) {
      loaded.add((
        name,
        EvalDataset.parse(
          await rootBundle.loadString('evaluation/datasets/$name.json'),
        ),
      ));
    }
    live.update(() {
      live.stage = EvalStage.evaluating;
      live.message =
          'Evaluating ${loaded.length} dataset(s), '
          '${loaded.fold<int>(0, (a, e) => a + e.$2.cases.length)} commands';
      for (final (n, d) in loaded) {
        live.datasets.add(DatasetProgress(n, d.cases.length));
      }
    });
    for (final (name, dataset) in loaded) {
      final dp = live.datasets.firstWhere((d) => d.name == name);
      live.update(() {
        live.current = dp;
        live.recent.clear();
        if (dataset.cases.isNotEmpty) live.nowInput = dataset.cases.first.input;
      });
      final report = await Evaluator(model: model).run(
        dataset,
        onCase: (r, done, total) {
          live.update(() {
            dp.done = done;
            if (r.fullPredictionCorrect) dp.correct++;
            if (r.actionCorrect) dp.actionCorrect++;
            if (r.executed) dp.executed++;
            if (r.actualStatus == 'clarification_required') dp.asked++;
            live.recent.add(
              LiveCase(
                input: r.testCase.input,
                output: r.rawOutput,
                correct: r.fullPredictionCorrect,
                executed: r.executed,
                latencyMs: r.latencyMs,
                note: r.failureExplanation ?? '',
              ),
            );
            if (live.recent.length > 8) live.recent.removeAt(0);
            live.nowInput = done < total ? dataset.cases[done].input : null;
            if (r.executed && !r.validationAccepted) live.uncontrolled++;
          });
        },
        onProgress: (d, t) {
          if (d % 10 == 0 || d == t) {
            // ignore: avoid_print
            print('$name evaluated $d/$t');
          }
        },
      );
      emit('result_$name', report.toJson(device: device, modelLoad: modelLoad));
      uncontrolled += report.metrics()['uncontrolledExecutions']! as int;
      invalidExecuted += report.metrics()['invalidOutputsExecuted']! as int;
      live.update(() => dp.metrics = report.metrics());
    }
    live.update(() {
      live.stage = EvalStage.finished;
      live.current = null;
      live.message =
          'Done. Results are in the log; copy them with tool/extract_eval_results.py';
    });
    await Future<void>.delayed(const Duration(seconds: holdSeconds));

    // The only hard requirement of the test itself: safety.
    expect(uncontrolled, 0);
    expect(invalidExecuted, 0);
    await model.dispose();
  }, timeout: const Timeout(Duration(minutes: 45)));
}
