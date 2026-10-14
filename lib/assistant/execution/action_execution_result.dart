enum ExecutionStatus { executed, failed }

class ActionExecutionResult {
  const ActionExecutionResult._(this.status, this.actionName, this.message);

  factory ActionExecutionResult.executed(String actionName, String message) =>
      ActionExecutionResult._(ExecutionStatus.executed, actionName, message);

  factory ActionExecutionResult.failed(String actionName, String message) =>
      ActionExecutionResult._(ExecutionStatus.failed, actionName, message);

  final ExecutionStatus status;
  final String actionName;
  final String message;

  bool get isExecuted => status == ExecutionStatus.executed;

  @override
  String toString() => 'ActionExecutionResult($status, $actionName, $message)';
}
