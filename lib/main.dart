import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_state.dart';
import 'app/assistant/assistant_controller.dart';
import 'app/home_shell.dart';
import 'app/model_host.dart';
import 'app/theme.dart';
import 'assistant/actions/action_registry.dart';
import 'assistant/execution/action_executor.dart';
import 'assistant/execution/assistant_pipeline.dart';
import 'assistant/providers/local_model_factory.dart';
import 'assistant/providers/model_catalog.dart';
import 'assistant/providers/model_prompt.dart';
import 'assistant/validation/action_validator.dart';

void main() => runApp(const AssistantPocApp());

/// Composition root: the only place where concrete choices are made (which
/// models exist, which prompt, which actions the AI may use). Everything else
/// depends on abstractions.
class AssistantPocApp extends StatefulWidget {
  const AssistantPocApp({super.key});

  @override
  State<AssistantPocApp> createState() => _AssistantPocAppState();
}

class _AssistantPocAppState extends State<AssistantPocApp> {
  // --dart-define=MODEL=gemma4|gemma4e4b|functiongemma  (default gemma4)
  // --dart-define=MODEL_FILE=/path/to/model.litertlm    (skip the download)
  // --dart-define=PROMPT=clarify_prompt_v4|recovery_prompt_v2|recovery_prompt_v1
  static const _modelId = String.fromEnvironment(
    'MODEL',
    defaultValue: 'gemma4',
  );
  static const _modelFile = String.fromEnvironment('MODEL_FILE');
  static const _promptId = String.fromEnvironment(
    'PROMPT',
    defaultValue: 'clarify_prompt_v4',
  );

  final AppState _state = AppState();
  late final ActionRegistry _registry = ActionRegistry.phase2();
  late final ModelHost _host = ModelHost(
    catalog: [
      ModelCatalog.gemma4E2b,
      ModelCatalog.gemma4E4b,
      ModelCatalog.functionGemma270m,
    ],
    initial: ModelCatalog.byId(_modelId),
    loader: (config) => createLocalModel(
      config.id,
      prompt: _prompt(),
      modelFilePath: config.id == _modelId && _modelFile.isNotEmpty
          ? _modelFile
          : null,
      // The AI is offered only what the registry contains, plus "ask the user".
      toolSpecs: _registry.toolSpecs(
        allowClarification: _prompt().id == promptClarifyV4.id,
      ),
    ),
  );
  late final AssistantController _assistant = AssistantController(
    pipeline: AssistantPipeline(
      ActionValidator(_registry),
      ActionExecutor(_registry, _state),
      registry: _registry,
    ),
    host: _host,
  );

  static PromptVersion _prompt() => switch (_promptId) {
    'recovery_prompt_v1' => promptRecoveryV1,
    'recovery_prompt_v2' => promptRecoveryV2,
    'recovery_prompt_v3' => promptRecoveryV3,
    _ => promptClarifyV4,
  };

  @override
  void dispose() {
    _assistant.dispose();
    _host.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => MaterialApp(
        title: 'Assistant',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: _state.flutterThemeMode,
        locale: _state.locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HomeShell(state: _state, host: _host, assistant: _assistant),
      ),
    );
  }
}
