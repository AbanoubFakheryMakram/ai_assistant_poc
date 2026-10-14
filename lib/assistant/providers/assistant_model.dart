import '../models/action_prediction.dart';

/// Anything that can turn user input into a (untrusted) prediction. The rest
/// of the app does not know or care whether it is an LLM, rules or a mock.
abstract interface class AssistantModel {
  Future<ActionPrediction> interpret(String input);
}

/// How the model's output looked before adaptation (evaluation bookkeeping).
enum ModelOutputKind {
  /// Exactly one function call.
  functionCall,

  /// Two or more function calls (never executed, never "first call wins").
  multipleCalls,

  /// Natural-language text and no function call.
  prose,

  /// Nothing at all.
  empty,

  /// Kind not reported (e.g. test doubles).
  unknown,
}

/// What a model produced for one input, with the evidence needed to debug and
/// compare models. [rawOutput] is the model's output BEFORE adaptation.
class ModelInterpretation {
  const ModelInterpretation({
    required this.prediction,
    required this.rawOutput,
    required this.latency,
    this.outputKind = ModelOutputKind.unknown,
  });
  final ModelOutputKind outputKind;
  final ActionPrediction prediction;
  final String rawOutput;
  final Duration latency;
}

/// An [AssistantModel] that can also report raw output and latency. The
/// evaluation runner depends only on this, so any local model can be evaluated on the same dataset and action contract.
abstract interface class TracedAssistantModel implements AssistantModel {
  /// Human-readable model name.
  String get modelName;

  /// Free-form description of runtime/format, recorded in result files.
  Map<String, Object?> get runtimeInfo;

  Future<ModelInterpretation> interpretWithTrace(String input);
}

/// Test/demo double returning predefined predictions. Not an AI.
class MockAssistantModel implements AssistantModel {
  MockAssistantModel(this._responses);
  final Map<String, ActionPrediction> _responses;

  @override
  Future<ActionPrediction> interpret(String input) async =>
      _responses[input] ??
      const ActionPrediction(
        status: 'unsupported',
        action: null,
        parameters: {},
      );
}

/// Timings and status of loading a model (informational, not pass/fail).
class ModelLoadReport {
  const ModelLoadReport({
    required this.installDuration,
    required this.loadDuration,
    required this.downloadedFromNetwork,
  });

  /// Time to make the model file available: includes the one-time download on
  /// first run; near zero when the file is already on disk.
  final Duration installDuration;

  /// Time to read the file and create the inference engine.
  final Duration loadDuration;
  final bool downloadedFromNetwork;
}

/// A [TracedAssistantModel] that must be loaded (and possibly downloaded)
/// before use. The UI and the evaluator depend on this interface only.
abstract interface class LoadableAssistantModel
    implements TracedAssistantModel {
  Future<ModelLoadReport> load({void Function(int percent)? onProgress});
  Future<void> dispose();
}
