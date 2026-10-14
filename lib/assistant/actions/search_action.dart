import '../execution/action_execution_result.dart';
import '../models/action_parameters.dart';
import 'assistant_action.dart';

/// Phase 1: only records the query so the UI can display it. No backend.
class SearchAction extends AssistantAction<SearchParameters> {
  const SearchAction();
  @override
  String get description =>
      'Search application content using a user-provided search query. It does not navigate to arbitrary URLs.';

  @override
  Map<String, Object?> get parametersSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'The text to search for, exactly as the user said it.',
      },
    },
    'required': ['query'],
  };

  @override
  String get name => 'search';

  @override
  SearchParameters readParameters(ParameterReader r) =>
      SearchParameters(r.nonEmptyString('query'));

  @override
  Future<ActionExecutionResult> execute(
    SearchParameters p,
    AssistantEnvironment env,
  ) async {
    env.setSearchQuery(p.query);
    return ActionExecutionResult.executed(name, 'Search query: "${p.query}"');
  }
}
