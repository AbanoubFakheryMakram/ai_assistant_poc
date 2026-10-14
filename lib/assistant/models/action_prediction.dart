import 'dart:convert';

/// Status of a prediction produced by any interpreter (AI or not).
/// Only [success] can ever lead to execution.
enum PredictionStatus {
  success('success'),
  clarificationRequired('clarification_required'),
  unsupported('unsupported');

  const PredictionStatus(this.wireName);
  final String wireName;

  static PredictionStatus? fromWire(Object? value) {
    for (final s in values) {
      if (s.wireName == value) return s;
    }
    return null;
  }
}

/// Untrusted, raw output of an interpreter:
/// `{"status": ..., "action": ..., "parameters": {...}}`.
///
/// Fields are deliberately kept loosely typed (`Object?`). Nothing in here is
/// trusted until the [ActionValidator] turns it into a typed `ValidatedAction`.
class ActionPrediction {
  const ActionPrediction({
    this.status,
    this.action,
    this.parameters,
    this.unexpectedKeys = const [],
    this.malformedReason,
  });

  /// Raw status value (expected: a String matching [PredictionStatus]).
  final Object? status;

  /// Raw action name (expected: a non-empty String, or null for non-success).
  final Object? action;

  /// Raw parameters (expected: a `Map<String, Object?>`).
  final Object? parameters;

  /// Top-level keys other than status/action/parameters.
  final List<String> unexpectedKeys;

  /// Set when the input could not even be parsed into an object.
  final String? malformedReason;

  bool get isMalformed => malformedReason != null;

  static const _knownKeys = {'status', 'action', 'parameters'};

  /// Builds a prediction from an already-decoded JSON value. Never throws.
  factory ActionPrediction.fromDecoded(Object? decoded) {
    if (decoded is! Map) {
      return ActionPrediction(
        malformedReason:
            'Prediction must be a JSON object, got '
            '${decoded == null ? 'null' : decoded.runtimeType}.',
      );
    }
    return ActionPrediction(
      status: decoded['status'],
      action: decoded['action'],
      parameters: decoded['parameters'],
      unexpectedKeys: [
        for (final k in decoded.keys)
          if (!_knownKeys.contains(k)) '$k',
      ],
    );
  }

  /// Parses a raw JSON string. Never throws; bad JSON yields a malformed
  /// prediction that the validator will reject.
  factory ActionPrediction.fromJsonString(String source) {
    try {
      return ActionPrediction.fromDecoded(jsonDecode(source));
    } on FormatException catch (e) {
      return ActionPrediction(malformedReason: 'Invalid JSON: ${e.message}');
    }
  }

  @override
  String toString() =>
      'ActionPrediction(status: $status, action: $action, parameters: $parameters)';
}
