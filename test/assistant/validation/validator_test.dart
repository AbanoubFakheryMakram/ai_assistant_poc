import 'package:assistant_poc/assistant/actions/action_registry.dart';
import 'package:assistant_poc/assistant/models/action_prediction.dart';
import 'package:assistant_poc/assistant/validation/action_validator.dart';
import 'package:assistant_poc/assistant/validation/validation_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final validator = ActionValidator(ActionRegistry.standard());

  void rejected(Object? decoded, RejectionReason reason) {
    final r = validator.validate(ActionPrediction.fromDecoded(decoded));
    expect(r, isA<ValidationRejected>());
    expect((r as ValidationRejected).reason, reason);
  }

  Map<String, Object?> s(Object? action, Object? params) => {
    'status': 'success',
    'action': action,
    'parameters': params,
  };

  group('invalid actions', () {
    test(
      'unknown',
      () =>
          rejected(s('some_unknown_action', {}), RejectionReason.unknownAction),
    );
    test(
      'missing',
      () => rejected({
        'status': 'success',
        'parameters': {},
      }, RejectionReason.missingAction),
    );
    test('null', () => rejected(s(null, {}), RejectionReason.missingAction));
    test(
      'non-string',
      () => rejected(s(1, {}), RejectionReason.malformedPrediction),
    );
  });

  group('invalid parameters', () {
    test(
      'missing mode',
      () => rejected(s('change_theme', {}), RejectionReason.missingParameter),
    );
    test(
      'invalid mode',
      () => rejected(
        s('change_theme', {'mode': 'blue'}),
        RejectionReason.invalidParameterValue,
      ),
    );
    test(
      'missing language',
      () =>
          rejected(s('change_language', {}), RejectionReason.missingParameter),
    );
    test(
      'invalid language',
      () => rejected(
        s('change_language', {'language': 'fr'}),
        RejectionReason.invalidParameterValue,
      ),
    );
    test(
      'missing destination',
      () => rejected(s('navigate', {}), RejectionReason.missingParameter),
    );
    test(
      'invalid destination',
      () => rejected(
        s('navigate', {'destination': 'some-arbitrary-route'}),
        RejectionReason.invalidParameterValue,
      ),
    );
    test(
      'missing enabled',
      () => rejected(
        s('toggle_notifications', {}),
        RejectionReason.missingParameter,
      ),
    );
    test(
      'wrong enabled type',
      () => rejected(
        s('toggle_notifications', {'enabled': 'yes'}),
        RejectionReason.invalidParameterType,
      ),
    );
    test(
      'empty query',
      () =>
          rejected(s('search', {'query': ''}), RejectionReason.emptyParameter),
    );
    test(
      'blank query',
      () => rejected(
        s('search', {'query': '   '}),
        RejectionReason.emptyParameter,
      ),
    );
    test(
      'query too long',
      () => rejected(
        s('search', {'query': 'x' * 201}),
        RejectionReason.parameterTooLong,
      ),
    );
  });

  group('security / robustness', () {
    test('malformed JSON', () {
      final r = validator.validate(
        ActionPrediction.fromJsonString('{"status": '),
      );
      expect(
        (r as ValidationRejected).reason,
        RejectionReason.malformedPrediction,
      );
    });
    test('JSON that is not an object', () {
      final r = validator.validate(ActionPrediction.fromJsonString('[1,2]'));
      expect(
        (r as ValidationRejected).reason,
        RejectionReason.malformedPrediction,
      );
    });
    test(
      'null parameters',
      () => rejected(s('change_theme', null), RejectionReason.nullParameters),
    );
    test(
      'parameters not an object',
      () => rejected(
        s('change_theme', 'dark'),
        RejectionReason.invalidParametersObject,
      ),
    );
    test(
      'unexpected parameter',
      () => rejected(
        s('change_theme', {'mode': 'dark', 'deleteEverything': true}),
        RejectionReason.unexpectedParameter,
      ),
    );
    test(
      'unexpected top-level field',
      () => rejected({
        ...s('change_theme', {'mode': 'dark'}),
        'callback': 'x',
      }, RejectionReason.unexpectedField),
    );
    test(
      'missing status',
      () => rejected({
        'action': 'change_theme',
        'parameters': {'mode': 'dark'},
      }, RejectionReason.unknownStatus),
    );
    test(
      'unknown status',
      () => rejected({
        ...s('change_theme', {'mode': 'dark'}),
        'status': 'ok',
      }, RejectionReason.unknownStatus),
    );
    test(
      'clarification_required',
      () => rejected({
        'status': 'clarification_required',
        'action': null,
        'parameters': {},
      }, RejectionReason.clarificationRequired),
    );
    test(
      'clarification_required even with a valid action',
      () => rejected({
        'status': 'clarification_required',
        'action': 'change_theme',
        'parameters': {'mode': 'dark'},
      }, RejectionReason.clarificationRequired),
    );
    test(
      'unsupported',
      () => rejected({
        'status': 'unsupported',
        'action': null,
        'parameters': {},
      }, RejectionReason.unsupportedRequest),
    );
  });
}
