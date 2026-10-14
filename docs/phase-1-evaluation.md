# Phase 1 evaluation

Command: `flutter test` (and `flutter analyze`: no issues).

## Test cases

| Suite | File | Tests |
|---|---|---|
| Valid actions (11 required + registry check) | `test/assistant/actions/actions_test.dart` | 12 |
| Validator: invalid action / invalid params / security | `test/assistant/validation/validator_test.dart` | 26 |
| Pipeline: rejected input never reaches executor (12), valid reaches once, foreign-registry refusal, mock model | `test/assistant/execution/pipeline_test.dart` | 15 |
| Dataset-driven (`evaluation/phase_1_commands.json`: 11 valid, 36 rejected) | same file | 47 |
| Demo screen widget test | `test/app/demo_screen_test.dart` | 1 |
| **Total** | | **101** |

"Not executed" tests assert both `SpyExecutor.executeCalls == 0` and that the
`RecordingEnvironment` received zero calls.

## Results

* Passed: 101 / 101
* Success rate: 100%
* Failed cases: none in the final run.

Two failures occurred during development and were fixed before this result:
1. "executor refuses an unregistered action": the test was wrong, not the code.
   `const` actions are canonicalised, so the "foreign" instance was identical to
   the registered one. The test now builds a non-const instance.
2. Widget test could not find the input: the default 800x600 test surface left it
   off-screen in a lazy `ListView`. The test now uses a taller surface.

## Conclusion

All 11 acceptance criteria are met: every registered action executes; unknown,
missing, invalid, extra-parameter, malformed, null-parameter and
non-`success` predictions are rejected and provably never executed; the app
works with no model; the registry is the only source of executable actions.

Phase 2 is **allowed to start** once the user explicitly approves.

## Caveats

* No natural-language evaluation exists yet (by design).
* Strict policy rejects payloads with no `status`, even if otherwise valid.
* Tested via `flutter test` only; the demo UI was not run on a device/emulator.
