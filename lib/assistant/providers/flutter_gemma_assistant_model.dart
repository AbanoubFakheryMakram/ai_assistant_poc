import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import '../models/action_prediction.dart';
import 'assistant_model.dart';
import 'local_model_config.dart';
import 'model_output_adapter.dart';
import '../actions/action_registry.dart';
import '../actions/tool_spec.dart';

/// A local model run through the flutter_gemma package, driven entirely by a
/// [LocalModelConfig]. This is the ONLY file in the project that imports
/// flutter_gemma; nothing here knows about a specific model. Everything it
/// returns is an untrusted [ActionPrediction] / plain strings.
class FlutterGemmaAssistantModel implements LoadableAssistantModel {
  FlutterGemmaAssistantModel(
    this.config, {
    List<ToolSpec>? toolSpecs,
    this.adapter = const ModelOutputAdapter(),
  }) : toolSpecs = toolSpecs ?? phase2ToolSpecs;

  final LocalModelConfig config;

  /// Tools exposed to the model, generated from the application contract.
  final List<ToolSpec> toolSpecs;
  final ModelOutputAdapter adapter;

  InferenceModel? _model;
  late final List<Tool> _tools = [
    for (final s in toolSpecs)
      Tool(name: s.name, description: s.description, parameters: s.parameters),
  ];

  bool get isLoaded => _model != null;

  @override
  String get modelName => config.displayName;

  @override
  Map<String, Object?> get runtimeInfo => {
    'model': modelName,
    'modelId': config.id,
    'modelSource': config.modelUrl,
    'modelFile': config.modelFileName,
    'modelFileFormat': 'litertlm',
    'runtime':
        'flutter_gemma 1.11.3 + flutter_gemma_litertlm 1.8.5 (LiteRT-LM)',
    'modelFamily': config.family.name,
    'backend': config.backend.name,
    'maxTokens': config.maxTokens,
    'maxOutputTokens': config.maxOutputTokens,
    'thinking': config.isThinking,
    'sampling': 'topK=${config.topK}, temperature=${config.temperature}',
    'promptVersion': config.prompt.id,
    'tools': [for (final t in _tools) t.name],
  };

  /// Downloads (first run only) and loads the model. Inference afterwards
  /// needs no network.
  @override
  Future<ModelLoadReport> load({void Function(int percent)? onProgress}) async {
    await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);

    final installWatch = Stopwatch()..start();
    var downloaded = false;
    final builder = FlutterGemma.installModel(
      modelType: _modelType(config.family),
      fileType: ModelFileType.litertlm,
    );
    final path = config.modelFilePath;
    if (path != null && path.isNotEmpty) {
      await builder.fromFile(path).install();
    } else {
      await builder.fromNetwork(config.modelUrl).withProgress((p) {
        downloaded = true;
        onProgress?.call(p);
      }).install();
    }
    installWatch.stop();

    final loadWatch = Stopwatch()..start();
    _model = await FlutterGemma.getActiveModel(
      maxTokens: config.maxTokens,
      preferredBackend: _backend(config.backend),
    );
    loadWatch.stop();

    return ModelLoadReport(
      installDuration: installWatch.elapsed,
      loadDuration: loadWatch.elapsed,
      downloadedFromNetwork: downloaded,
    );
  }

  @override
  Future<ActionPrediction> interpret(String input) async =>
      (await interpretWithTrace(input)).prediction;

  @override
  Future<ModelInterpretation> interpretWithTrace(String input) async {
    final model = _model;
    if (model == null) {
      throw StateError('Call load() before interpret().');
    }
    final watch = Stopwatch()..start();
    // A fresh, stateless chat per request: no history leaks between commands.
    final chat = await model.createChat(
      tools: _tools,
      supportsFunctionCalls: true,
      modelType: _modelType(config.family),
      isThinking: config.isThinking,
      systemInstruction: config.prompt.build([for (final t in _tools) t.name]),
      temperature: config.temperature,
      topK: config.topK,
      maxOutputTokens: config.maxOutputTokens,
    );
    RawModelOutput raw;
    try {
      await chat.addQueryChunk(Message(text: input, isUser: true));
      raw = _collect(await chat.generateChatResponse());
    } finally {
      await chat.close();
    }
    watch.stop();
    return ModelInterpretation(
      prediction: adapter.adapt(raw),
      rawOutput: raw.describe(),
      latency: watch.elapsed,
      outputKind: raw.kind,
    );
  }

  @override
  Future<void> dispose() async {
    await _model?.close();
    _model = null;
  }

  static ModelType _modelType(ModelFamily f) => switch (f) {
    ModelFamily.functionGemma => ModelType.functionGemma,
    ModelFamily.gemma4 => ModelType.gemma4,
    ModelFamily.qwen3 => ModelType.qwen3,
  };

  static PreferredBackend _backend(InferenceBackend b) => switch (b) {
    InferenceBackend.cpu => PreferredBackend.cpu,
    InferenceBackend.gpu => PreferredBackend.gpu,
    InferenceBackend.npu => PreferredBackend.npu,
  };

  RawModelOutput _collect(ModelResponse r) => switch (r) {
    FunctionCallResponse(:final name, :final args) => RawModelOutput(
      calls: [RawFunctionCall(name, args)],
    ),
    ParallelFunctionCallResponse(:final calls) => RawModelOutput(
      calls: [for (final c in calls) RawFunctionCall(c.name, c.args)],
    ),
    TextResponse(:final token) => RawModelOutput(text: token),
    ThinkingResponse(:final content) => RawModelOutput(text: content),
  };
}
