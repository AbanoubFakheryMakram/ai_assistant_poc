import 'flutter_gemma_assistant_model.dart';
import 'assistant_model.dart';
import 'local_model_config.dart';
import 'model_catalog.dart';
import 'model_prompt.dart';
import '../actions/tool_spec.dart';

/// Composition helper: builds a loadable local model from a catalog id. This is
/// the only place that connects the data (catalog) to the runtime.
LoadableAssistantModel createLocalModel(
  String modelId, {
  String? modelFilePath,
  PromptVersion? prompt,
  List<ToolSpec>? toolSpecs,
}) {
  final LocalModelConfig config = ModelCatalog.byId(
    modelId,
  ).copyWith(prompt: prompt, modelFilePath: modelFilePath);
  return FlutterGemmaAssistantModel(config, toolSpecs: toolSpecs);
}
