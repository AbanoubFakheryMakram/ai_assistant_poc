import 'eval_dataset.dart';

enum FailureCategory {
  wrongAction('wrong_action'),
  wrongParameter('wrong_parameter'),
  fabricatedParameter('fabricated_parameter'),
  malformedOutput('malformed_output'),
  multipleFunctionCalls('multiple_function_calls'),
  proseOutput('prose_output'),
  unsupportedRequestMappedToAction('unsupported_request_mapped_to_action'),
  languageFailure('language_failure'),
  mixedLanguageFailure('mixed_language_failure'),
  other('other');

  const FailureCategory(this.wireName);
  final String wireName;
}

class CaseResult {
  CaseResult({
    required this.testCase,
    required this.rawOutput,
    required this.actualStatus,
    required this.actualAction,
    required this.actualParameters,
    required this.malformedReason,
    required this.validationAccepted,
    required this.rejectionReason,
    required this.rejectionMessage,
    required this.executed,
    required this.latencyMs,
    required this.statusCorrect,
    required this.actionCorrect,
    required this.parametersCorrect,
    required this.fullPredictionCorrect,
    required this.invalidOutput,
    required this.fabricatedParameter,
    required this.failureCategory,
    required this.failureExplanation,
    required this.outputKind,
    required this.failureTags,
    this.clarifyTargetCorrect,
  });

  final EvalCase testCase;
  final String rawOutput;
  final Object? actualStatus;
  final Object? actualAction;
  final Object? actualParameters;
  final String? malformedReason;
  final bool validationAccepted;
  final String? rejectionReason;
  final String? rejectionMessage;
  final bool executed;
  final int latencyMs;
  final bool statusCorrect;
  final bool actionCorrect;
  final bool parametersCorrect;
  final bool fullPredictionCorrect;
  final bool invalidOutput;
  final bool fabricatedParameter;
  final FailureCategory? failureCategory;
  final String? failureExplanation;
  final String outputKind;

  /// Secondary, non-exclusive diagnostic tags (prose_output,
  /// multiple_function_calls, navigate_profile_collapse).
  final List<String> failureTags;

  /// For a vague request answered with a question: did it ask about the right
  /// missing value? Null when not applicable.
  final bool? clarifyTargetCorrect;

  Map<String, Object?> toJson() => {
    'id': testCase.id,
    'language': testCase.language,
    'input': testCase.input,
    'expected': testCase.expected.toJson(),
    'rawModelOutput': rawOutput,
    'actual': {
      'status': actualStatus,
      'action': actualAction,
      'parameters': actualParameters,
      if (malformedReason != null) 'malformedReason': malformedReason,
    },
    'validation': {
      'accepted': validationAccepted,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (rejectionMessage != null) 'message': rejectionMessage,
    },
    'executed': executed,
    'latencyMs': latencyMs,
    'statusCorrect': statusCorrect,
    'actionCorrect': actionCorrect,
    'parametersCorrect': parametersCorrect,
    'fullPredictionCorrect': fullPredictionCorrect,
    'outputKind': outputKind,
    'failureTags': failureTags,
    if (clarifyTargetCorrect != null)
      'clarifyTargetCorrect': clarifyTargetCorrect,
    'invalidOutput': invalidOutput,
    'fabricatedParameter': fabricatedParameter,
    if (failureCategory != null) 'failureCategory': failureCategory!.wireName,
    if (failureExplanation != null) 'failureExplanation': failureExplanation,
  };
}
