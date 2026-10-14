import 'dart:convert';

import '../actions/action_registry.dart';
import '../actions/assistant_action.dart';
import '../execution/action_executor.dart';
import '../execution/assistant_pipeline.dart';
import '../models/action_parameters.dart';
import '../models/action_prediction.dart';
import '../providers/assistant_model.dart';
import '../actions/tool_spec.dart';
import '../validation/action_validator.dart';
import '../validation/validation_result.dart';
import 'eval_dataset.dart';
import 'eval_result.dart';

/// Counts environment calls; the evaluation never touches a real app.
class CountingEnvironment implements AssistantEnvironment {
  int calls = 0;
  @override
  void navigateTo(AppDestination destination) => calls++;
  @override
  void setLanguage(AppLanguage language) => calls++;
  @override
  void setNotificationsEnabled(bool enabled) => calls++;
  @override
  void setSearchQuery(String query) => calls++;
  @override
  void setThemeMode(ThemeModeOption mode) => calls++;
}

class EvalReport {
  EvalReport({
    required this.dataset,
    required this.model,
    required this.cases,
    required this.executedCalls,
    required this.environmentCalls,
  });
  final EvalDataset dataset;
  final TracedAssistantModel model;
  final List<CaseResult> cases;
  final int executedCalls;
  final int environmentCalls;

  int get total => cases.length;

  static double _pct(int n, int d) => d == 0 ? 0 : (n / d) * 100;

  /// Cases that expect a successful action call.
  List<CaseResult> get _expectSuccess =>
      cases.where((c) => c.testCase.expected.isSuccess).toList();

  Map<String, Object?> metrics() {
    int count(bool Function(CaseResult) f) => cases.where(f).length;
    final es = _expectSuccess;
    final executedWithoutValidation = cases
        .where((c) => c.executed && !c.validationAccepted)
        .length;
    final invalid = cases.where((c) => c.invalidOutput).toList();
    return {
      'totalCommands': total,
      'actionAccuracyPct': _pct(count((c) => c.actionCorrect), total),
      // Denominator: cases that expect parameters (successful actions).
      'parameterAccuracyPct': _pct(
        es.where((c) => c.parametersCorrect).length,
        es.length,
      ),
      // Same numerator rule over ALL cases (negatives count when params are empty).
      'parameterAccuracyAllCasesPct': _pct(
        count((c) => c.parametersCorrect),
        total,
      ),
      'fullPredictionAccuracyPct': _pct(
        count((c) => c.fullPredictionCorrect),
        total,
      ),
      'statusAccuracyPct': _pct(count((c) => c.statusCorrect), total),
      'invalidOutputRatePct': _pct(invalid.length, total),
      'invalidOutputsExecuted': invalid.where((c) => c.executed).length,
      'multipleFunctionCallRatePct': _pct(
        count((c) => c.outputKind == 'multipleCalls'),
        total,
      ),
      'proseOutputRatePct': _pct(count((c) => c.outputKind == 'prose'), total),
      'navigateProfileCollapseCases': count(
        (c) => c.failureTags.contains('navigate_profile_collapse'),
      ),
      // Stricter variant: prose output is treated as invalid even when the
      // case expected a refusal.
      'fullPredictionAccuracyProseAsInvalidPct': _pct(
        count((c) => c.fullPredictionCorrect && c.outputKind != 'prose'),
        total,
      ),
      // Round 3: how often the model asked the user instead of guessing.
      'askedUserCases': count(
        (c) => c.actualStatus == 'clarification_required',
      ),
      'askedUserOfVagueCases': _askedOfVague(),
      'vagueCases': cases
          .where((c) => c.testCase.expected.status == 'clarification_required')
          .length,
      'askedUserWithCorrectTarget': count(
        (c) => c.clarifyTargetCorrect == true,
      ),
      'askedUserWhereNotExpected': count(
        (c) =>
            c.actualStatus == 'clarification_required' &&
            !c.testCase.expected.acceptableStatuses.contains(
              'clarification_required',
            ),
      ),
      'fabricatedParameterRatePct': _pct(
        count((c) => c.fabricatedParameter),
        total,
      ),
      'fabricatedParameterCases': count((c) => c.fabricatedParameter),
      'uncontrolledExecutions': executedWithoutValidation,
      'executedActions': executedCalls,
      'environmentCalls': environmentCalls,
      'expectSuccessCases': es.length,
      'expectNonSuccessCases': total - es.length,
    };
  }

  int _askedOfVague() => cases
      .where(
        (c) =>
            c.testCase.expected.status == 'clarification_required' &&
            c.actualStatus == 'clarification_required',
      )
      .length;

  Map<String, Object?> languageBreakdown() {
    final langs = <String>{for (final c in cases) c.testCase.language};
    return {
      for (final l in langs.toList()..sort())
        l: () {
          final cs = cases.where((c) => c.testCase.language == l).toList();
          int n(bool Function(CaseResult) f) => cs.where(f).length;
          final es = cs.where((c) => c.testCase.expected.isSuccess).toList();
          return {
            'total': cs.length,
            'actionAccuracyPct': _pct(n((c) => c.actionCorrect), cs.length),
            'parameterAccuracyPct': _pct(
              es.where((c) => c.parametersCorrect).length,
              es.length,
            ),
            'fullPredictionAccuracyPct': _pct(
              n((c) => c.fullPredictionCorrect),
              cs.length,
            ),
          };
        }(),
    };
  }

  Map<String, Object?> failureSummary() {
    final by = <String, int>{};
    for (final c in cases.where((c) => !c.fullPredictionCorrect)) {
      final k = c.failureCategory?.wireName ?? 'other';
      by[k] = (by[k] ?? 0) + 1;
    }
    return {
      'failedCases': cases.where((c) => !c.fullPredictionCorrect).length,
      'byCategory': by,
    };
  }

  Map<String, Object?> latency() {
    final ms = [for (final c in cases) c.latencyMs];
    if (ms.isEmpty) return {};
    final rest = ms.skip(1).toList();
    return {
      'firstInferenceMs': ms.first,
      'subsequentAverageMs': rest.isEmpty
          ? null
          : rest.reduce((a, b) => a + b) / rest.length,
      'subsequentMinMs': rest.isEmpty
          ? null
          : rest.reduce((a, b) => a < b ? a : b),
      'subsequentMaxMs': rest.isEmpty
          ? null
          : rest.reduce((a, b) => a > b ? a : b),
    };
  }

  Map<String, Object?> toJson({
    Map<String, Object?> device = const {},
    Map<String, Object?> modelLoad = const {},
  }) => {
    'dataset': dataset.name,
    'datasetVersion': dataset.version,
    'runAt': DateTime.now().toUtc().toIso8601String(),
    'model': model.runtimeInfo,
    'device': device,
    'modelLoad': modelLoad,
    'metrics': metrics(),
    'languageBreakdown': languageBreakdown(),
    'latency': latency(),
    'failureSummary': failureSummary(),
    'failures': [
      for (final c in cases.where((c) => !c.fullPredictionCorrect))
        {
          'id': c.testCase.id,
          'input': c.testCase.input,
          'expected': c.testCase.expected.toJson(),
          'actual': {
            'status': c.actualStatus,
            'action': c.actualAction,
            'parameters': c.actualParameters,
          },
          'rawModelOutput': c.rawOutput,
          'failureCategory': c.failureCategory?.wireName ?? 'other',
          'explanation': c.failureExplanation,
        },
    ],
    'cases': [for (final c in cases) c.toJson()],
  };
}

/// Runs a dataset through a model, the adapter, the normal validator and the
/// normal executor, and scores the result. Contains no dataset-specific rules.
class Evaluator {
  Evaluator({
    required this.model,
    ActionRegistry? registry,
    List<ToolSpec>? toolSpecs,
  }) : registry = registry ?? ActionRegistry.phase2(),
       toolSpecs = toolSpecs ?? phase2ToolSpecs;

  final TracedAssistantModel model;
  final ActionRegistry registry;
  final List<ToolSpec> toolSpecs;

  Future<EvalReport> run(
    EvalDataset dataset, {
    void Function(int done, int total)? onProgress,

    /// Called after every case with its full result (for live displays).
    void Function(CaseResult result, int done, int total)? onCase,
  }) async {
    final env = CountingEnvironment();
    final pipeline = AssistantPipeline(
      ActionValidator(registry),
      ActionExecutor(registry, env),
      registry: registry,
    );
    final results = <CaseResult>[];
    var executed = 0;
    for (var i = 0; i < dataset.cases.length; i++) {
      final c = dataset.cases[i];
      final r = await _runCase(c, pipeline);
      if (r.executed) executed++;
      results.add(r);
      onProgress?.call(i + 1, dataset.cases.length);
      onCase?.call(r, i + 1, dataset.cases.length);
    }
    return EvalReport(
      dataset: dataset,
      model: model,
      cases: results,
      executedCalls: executed,
      environmentCalls: env.calls,
    );
  }

  Future<CaseResult> _runCase(EvalCase c, AssistantPipeline pipeline) async {
    ModelInterpretation interp;
    try {
      interp = await model.interpretWithTrace(c.input);
    } catch (e) {
      interp = ModelInterpretation(
        prediction: ActionPrediction(malformedReason: 'Model error: $e'),
        rawOutput: 'ERROR: $e',
        latency: Duration.zero,
      );
    }
    final p = interp.prediction;
    final outcome = await pipeline.process(p);
    return _score(c, interp, outcome);
  }

  CaseResult _score(EvalCase c, ModelInterpretation i, PipelineOutcome o) {
    final p = i.prediction;
    final kind = i.outputKind;
    final exp = c.expected;
    final accepted = o.validation is ValidationAccepted;
    final rejected = o.validation is ValidationRejected
        ? o.validation as ValidationRejected
        : null;
    final executed = o.execution?.isExecuted ?? false;

    final actualStatus = p.isMalformed ? null : p.status;
    final actualAction = p.isMalformed ? null : p.action;
    final actualParams = p.isMalformed ? null : p.parameters;
    final params = actualParams is Map
        ? Map<Object?, Object?>.from(actualParams)
        : <Object?, Object?>{};

    final statusCorrect =
        !p.isMalformed && exp.acceptableStatuses.contains(actualStatus);
    final actionCorrect = !p.isMalformed && actualAction == exp.action;
    // A refusal or a question has no parameters to compare: when neither the
    // expectation nor the prediction is an action, correctness is the status.
    final bothNonAction = !exp.isSuccess && actualStatus != 'success';
    final parametersCorrect =
        !p.isMalformed &&
        (bothNonAction ? statusCorrect : _sameMap(params, exp.parameters));
    final isSuccessPred = actualStatus == 'success';

    final invalidOutput = p.isMalformed || (isSuccessPred && rejected != null);

    // Fabrication: parameter content the user input did not support.
    var fabricated = false;
    if (isSuccessPred && params.isNotEmpty) {
      if (!exp.isSuccess) {
        fabricated = true; // values invented for a request with no basis
      } else if (actionCorrect) {
        final allowed = _allowedValues(actualAction as String);
        for (final e in params.entries) {
          final inExpected = exp.parameters.containsKey(e.key);
          final domain = allowed[e.key];
          final outOfDomain = domain != null && !domain.contains(e.value);
          if (!inExpected || outOfDomain) fabricated = true;
        }
      } else {
        // wrong action: arguments for it are not grounded either if outside its domain
        final allowed = _allowedValues('${actualAction ?? ''}');
        for (final e in params.entries) {
          final domain = allowed[e.key];
          if (domain != null && !domain.contains(e.value)) fabricated = true;
        }
      }
    }

    final full =
        statusCorrect &&
        actionCorrect &&
        parametersCorrect &&
        (!exp.isSuccess || (accepted && executed));

    FailureCategory? cat;
    String? why;
    if (!full) {
      (cat, why) = _classify(
        c: c,
        p: p,
        kind: kind,
        actualStatus: actualStatus,
        actualAction: actualAction,
        statusCorrect: statusCorrect,
        actionCorrect: actionCorrect,
        parametersCorrect: parametersCorrect,
        fabricated: fabricated,
        rejected: rejected,
      );
    }

    final tags = <String>[
      if (kind == ModelOutputKind.prose) 'prose_output',
      if (kind == ModelOutputKind.multipleCalls) 'multiple_function_calls',
      if (actualAction == 'navigate' &&
          params['destination'] == 'profile' &&
          !(exp.action == 'navigate' &&
              exp.parameters['destination'] == 'profile'))
        'navigate_profile_collapse',
    ];

    return CaseResult(
      testCase: c,
      outputKind: kind.name,
      failureTags: tags,
      clarifyTargetCorrect:
          (actualStatus == 'clarification_required' &&
              exp.clarifyTarget != null)
          ? params['target'] == exp.clarifyTarget
          : null,
      rawOutput: i.rawOutput,
      actualStatus: actualStatus,
      actualAction: actualAction,
      actualParameters: _jsonSafe(actualParams),
      malformedReason: p.malformedReason,
      validationAccepted: accepted,
      rejectionReason: rejected?.reason.name,
      rejectionMessage: rejected?.message,
      executed: executed,
      latencyMs: i.latency.inMilliseconds,
      statusCorrect: statusCorrect,
      actionCorrect: actionCorrect,
      parametersCorrect: parametersCorrect,
      fullPredictionCorrect: full,
      invalidOutput: invalidOutput,
      fabricatedParameter: fabricated,
      failureCategory: cat,
      failureExplanation: why,
    );
  }

  (FailureCategory, String) _classify({
    required EvalCase c,
    required ActionPrediction p,
    required ModelOutputKind kind,
    required Object? actualStatus,
    required Object? actualAction,
    required bool statusCorrect,
    required bool actionCorrect,
    required bool parametersCorrect,
    required bool fabricated,
    required ValidationRejected? rejected,
  }) {
    final exp = c.expected;
    if (p.isMalformed) {
      if (kind == ModelOutputKind.multipleCalls) {
        return (
          FailureCategory.multipleFunctionCalls,
          'Model emitted several function calls; none executed. ${p.malformedReason}',
        );
      }
      return (
        FailureCategory.malformedOutput,
        'Output could not be converted: ${p.malformedReason}',
      );
    }
    if (!exp.isSuccess) {
      if (actualStatus == 'success') {
        if (exp.status == 'clarification_required' && fabricated) {
          return (
            FailureCategory.fabricatedParameter,
            'Required value was missing from the request but the model called $actualAction with ${p.parameters}.',
          );
        }
        return (
          FailureCategory.unsupportedRequestMappedToAction,
          'Request should not map to an exposed action but the model called $actualAction with ${p.parameters}.',
        );
      }
      return (FailureCategory.other, 'Unexpected status $actualStatus.');
    }
    // Expected a successful call.
    if (actualStatus != 'success') {
      if (kind == ModelOutputKind.prose) {
        return (
          FailureCategory.proseOutput,
          'Model answered in prose instead of calling ${exp.action}.',
        );
      }
      final cat = switch (c.language) {
        'mixed' => FailureCategory.mixedLanguageFailure,
        'english' => FailureCategory.wrongAction,
        _ => FailureCategory.languageFailure,
      };
      return (
        cat,
        'Model made no function call for a command that maps to ${exp.action}.',
      );
    }
    if (!actionCorrect) {
      return (
        FailureCategory.wrongAction,
        'Expected ${exp.action}, model called $actualAction.',
      );
    }
    if (fabricated) {
      return (
        FailureCategory.fabricatedParameter,
        'Parameters ${p.parameters} contain invented keys/values (expected ${exp.parameters}).',
      );
    }
    if (!parametersCorrect) {
      return (
        FailureCategory.wrongParameter,
        'Expected ${exp.parameters}, model gave ${p.parameters}.',
      );
    }
    if (rejected != null) {
      return (
        FailureCategory.other,
        'Validator rejected: ${rejected.reason.name}.',
      );
    }
    return (FailureCategory.other, 'Unclassified mismatch.');
  }

  /// Allowed enum values per parameter, from the exposed tool schema.
  Map<String, List<Object?>> _allowedValues(String action) {
    for (final s in toolSpecs) {
      if (s.name != action) continue;
      final props = s.parameters['properties'];
      if (props is! Map) return {};
      return {
        for (final e in props.entries)
          if (e.value is Map && (e.value as Map)['enum'] is List)
            e.key as String: List<Object?>.from(
              (e.value as Map)['enum'] as List,
            ),
      };
    }
    return {};
  }

  static bool _sameMap(Map<Object?, Object?> a, Map<Object?, Object?> b) =>
      jsonEncode(_sorted(a)) == jsonEncode(_sorted(b));

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final e in v) _sorted(e)];
    return v;
  }

  static Object? _jsonSafe(Object? v) {
    try {
      jsonEncode(v);
      return v;
    } catch (_) {
      return '$v';
    }
  }
}
