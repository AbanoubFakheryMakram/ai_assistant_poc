import 'local_model_config.dart';
import 'model_prompt.dart';

/// The local models this project has evaluated, as data. Adding a model means
/// adding an entry here; no other code changes.
abstract final class ModelCatalog {
  /// FunctionGemma 270M: the Phase 2 baseline (native tool-call channel).
  static final functionGemma270m = LocalModelConfig(
    id: 'functiongemma',
    displayName: 'FunctionGemma 270M',
    family: ModelFamily.functionGemma,
    modelUrl:
        'https://huggingface.co/sasha-denisov/function-gemma-270M-it/resolve/main/functiongemma-270M-it.litertlm',
    modelFileName: 'functiongemma-270M-it.litertlm',
    approxSizeMb: 284,
    prompt: promptFunctionGemmaV1,
    maxTokens: 1024,
    maxOutputTokens: 128,
  );

  /// Qwen3 0.6B INT8. Does not load on the iOS Simulator with the current
  /// runtime (see docs/phase-2-recovery.md); kept so the result is reproducible.
  static final qwen3_0_6b = LocalModelConfig(
    id: 'qwen3',
    displayName: 'Qwen3 0.6B',
    family: ModelFamily.qwen3,
    modelUrl:
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
    modelFileName: 'Qwen3-0.6B.litertlm',
    approxSizeMb: 614,
    prompt: promptRecoveryV1,
  );

  static final gemma4E2b = LocalModelConfig(
    id: 'gemma4',
    displayName: 'Gemma 4 E2B',
    family: ModelFamily.gemma4,
    modelUrl:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    modelFileName: 'gemma-4-E2B-it.litertlm',
    approxSizeMb: 2468,
    prompt: promptRecoveryV1,
  );

  static final gemma4E4b = LocalModelConfig(
    id: 'gemma4e4b',
    displayName: 'Gemma 4 E4B',
    family: ModelFamily.gemma4,
    modelUrl:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    modelFileName: 'gemma-4-E4B-it.litertlm',
    approxSizeMb: 3490,
    prompt: promptRecoveryV1,
  );

  static final all = <LocalModelConfig>[
    functionGemma270m,
    qwen3_0_6b,
    gemma4E2b,
    gemma4E4b,
  ];

  static LocalModelConfig byId(String id) => all.firstWhere(
    (m) => m.id == id,
    orElse: () => throw ArgumentError(
      'Unknown model "$id". Known: ${all.map((m) => m.id).join(', ')}',
    ),
  );
}
