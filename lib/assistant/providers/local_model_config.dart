import 'model_prompt.dart';

/// Model families the local runtime knows how to talk to. This is the runtime's
/// own vocabulary; it deliberately does not expose any third-party package type.
enum ModelFamily { functionGemma, gemma4, qwen3 }

enum InferenceBackend { cpu, gpu, npu }

/// Everything that distinguishes one local model from another. It is plain
/// data: no package types, no behaviour. The runtime, adapter, validator and
/// executor are shared by every model.
class LocalModelConfig {
  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.family,
    required this.modelUrl,
    required this.modelFileName,
    required this.approxSizeMb,
    required this.prompt,
    this.backend = InferenceBackend.cpu,
    this.maxTokens = 4096,
    this.maxOutputTokens = 256,
    this.isThinking = false,
    this.temperature = 0.1,
    this.topK = 1,
    this.modelFilePath,
  });

  /// Stable identifier used on the command line and in result files.
  final String id;
  final String displayName;
  final ModelFamily family;

  /// Where the model file is published (used for the one-time download).
  final String modelUrl;
  final String modelFileName;
  final int approxSizeMb;
  final PromptVersion prompt;
  final InferenceBackend backend;

  /// Context window (input + output). Not the reply length.
  final int maxTokens;
  final int maxOutputTokens;
  final bool isThinking;
  final double temperature;
  final int topK;

  /// If set, install from this local file instead of downloading (developer
  /// convenience; the file is the one published at [modelUrl]).
  final String? modelFilePath;

  LocalModelConfig copyWith({PromptVersion? prompt, String? modelFilePath}) =>
      LocalModelConfig(
        id: id,
        displayName: displayName,
        family: family,
        modelUrl: modelUrl,
        modelFileName: modelFileName,
        approxSizeMb: approxSizeMb,
        prompt: prompt ?? this.prompt,
        backend: backend,
        maxTokens: maxTokens,
        maxOutputTokens: maxOutputTokens,
        isThinking: isThinking,
        temperature: temperature,
        topK: topK,
        modelFilePath: modelFilePath ?? this.modelFilePath,
      );
}
