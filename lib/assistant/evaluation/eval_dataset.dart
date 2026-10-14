import 'dart:convert';

/// Expected outcome, fixed in the dataset BEFORE any model runs.
class ExpectedResult {
  const ExpectedResult({
    required this.status,
    required this.action,
    required this.parameters,
    required this.acceptableStatuses,
    this.clarifyTarget,
  });

  /// "success" | "clarification_required" | "unsupported"
  final String status;
  final String? action;
  final Map<String, Object?> parameters;

  /// Statuses that count as correct. For non-success cases where either a
  /// refusal or a clarification request is reasonable, both are listed.
  final List<String> acceptableStatuses;

  /// For vague requests: which missing value a good answer asks about, e.g.
  /// `change_theme.mode`. Recorded for scoring the question, not required.
  final String? clarifyTarget;

  bool get isSuccess => status == 'success';

  factory ExpectedResult.fromJson(Map<String, Object?> j) {
    final status = j['status']! as String;
    return ExpectedResult(
      status: status,
      action: j['action'] as String?,
      parameters: Map<String, Object?>.from(
        (j['parameters'] as Map?) ?? const <String, Object?>{},
      ),
      clarifyTarget: j['clarifyTarget'] as String?,
      acceptableStatuses: [
        for (final s in (j['acceptableStatuses'] as List?) ?? [status])
          s as String,
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'status': status,
    'action': action,
    'parameters': parameters,
    if (clarifyTarget != null) 'clarifyTarget': clarifyTarget,
    if (acceptableStatuses.length > 1) 'acceptableStatuses': acceptableStatuses,
  };
}

class EvalCase {
  const EvalCase({
    required this.id,
    required this.language,
    required this.input,
    required this.expected,
  });
  final String id;

  /// english | msa_arabic | egyptian_arabic | mixed
  final String language;
  final String input;
  final ExpectedResult expected;

  factory EvalCase.fromJson(Map<String, Object?> j) => EvalCase(
    id: j['id']! as String,
    language: j['language']! as String,
    input: j['input']! as String,
    expected: ExpectedResult.fromJson(
      Map<String, Object?>.from(j['expected']! as Map),
    ),
  );
}

class EvalDataset {
  const EvalDataset(this.name, this.version, this.cases);
  final String name;
  final int version;
  final List<EvalCase> cases;

  factory EvalDataset.parse(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    return EvalDataset(j['dataset']! as String, j['version']! as int, [
      for (final c in j['cases']! as List)
        EvalCase.fromJson(Map<String, Object?>.from(c as Map)),
    ]);
  }
}
