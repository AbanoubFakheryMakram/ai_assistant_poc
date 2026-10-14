import 'package:flutter/foundation.dart';

import '../assistant/providers/assistant_model.dart';
import '../assistant/providers/local_model_config.dart';

enum ModelStatus { notLoaded, loading, ready, error }

/// UI-facing holder for a local model. It knows only the abstractions
/// ([LoadableAssistantModel], [LocalModelConfig]); which concrete runtime builds
/// the model is decided by the loader that `main.dart` supplies.
class ModelHost extends ChangeNotifier {
  ModelHost({
    required this.catalog,
    required this.loader,
    LocalModelConfig? initial,
  }) : selected = initial ?? catalog.first;

  final List<LocalModelConfig> catalog;

  /// Creates a loadable model for a config.
  final LoadableAssistantModel Function(LocalModelConfig config) loader;

  LocalModelConfig selected;
  ModelStatus status = ModelStatus.notLoaded;
  int? progress;
  String? error;
  LoadableAssistantModel? _loaded;
  ModelLoadReport? report;

  /// The model to interpret with, only while it is ready.
  TracedAssistantModel? get model =>
      status == ModelStatus.ready ? _loaded : null;

  Future<void> load([LocalModelConfig? config]) async {
    if (status == ModelStatus.loading) return;
    if (config != null && config.id != selected.id) {
      await _loaded?.dispose();
      _loaded = null;
      status = ModelStatus.notLoaded;
      selected = config;
    }
    if (status == ModelStatus.ready) return;
    status = ModelStatus.loading;
    progress = null;
    error = null;
    notifyListeners();
    try {
      final m = loader(selected);
      report = await m.load(
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
      _loaded = m;
      status = ModelStatus.ready;
    } catch (e) {
      status = ModelStatus.error;
      error = '$e';
    }
    notifyListeners();
  }
}
