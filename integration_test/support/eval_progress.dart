import 'package:flutter/foundation.dart';

enum EvalStage {
  preparing,
  downloading,
  loading,
  sanity,
  evaluating,
  finished,
  failed,
}

/// One finished command, as shown in the live list.
class LiveCase {
  LiveCase({
    required this.input,
    required this.output,
    required this.correct,
    required this.executed,
    required this.latencyMs,
    required this.note,
  });
  final String input;
  final String output;
  final bool correct;
  final bool executed;
  final int latencyMs;
  final String note;
}

class DatasetProgress {
  DatasetProgress(this.name, this.total);
  final String name;
  final int total;
  int done = 0;
  int correct = 0;
  int actionCorrect = 0;
  int executed = 0;
  int asked = 0;
  Map<String, Object?>? metrics;
}

/// Everything the live screen shows. The test updates it; the screen listens.
class EvalProgress extends ChangeNotifier {
  EvalProgress({
    required this.modelName,
    required this.promptId,
    required this.device,
  });

  final String modelName;
  final String promptId;
  final String device;

  EvalStage stage = EvalStage.preparing;
  String message = 'Starting…';
  int? downloadPercent;
  int? loadMs;
  final List<DatasetProgress> datasets = [];
  DatasetProgress? current;
  String? nowInput;
  final List<LiveCase> recent = [];
  final List<LiveCase> sanity = [];
  String? error;
  final DateTime startedAt = DateTime.now();
  int uncontrolled = 0;

  void update(void Function() change) {
    change();
    notifyListeners();
  }
}
