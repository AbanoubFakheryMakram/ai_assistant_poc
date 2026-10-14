# Datasets and scoring

All datasets are JSON files in `evaluation/datasets/`. Every case has an `id`, a `language`
(`english`, `msa_arabic`, `egyptian_arabic`, `mixed`), an `input`, and an `expected` result **written before any model ran**.

```json
{ "id": "theme-egy-002", "language": "egyptian_arabic", "input": "...",
  "expected": { "status": "success", "action": "change_theme", "parameters": { "mode": "dark" } } }
```

Non-action cases use `status: "unsupported"` (the request is outside what the app can do) or
`status: "clarification_required"` (a needed value is missing; `acceptableStatuses` lists both a question and a refusal as
correct, and `clarifyTarget` names the value a good question asks about).

## The datasets

| File | Cases | Status |
|---|---:|---|
| `evaluation/phase_1_commands.json` | 47 | Phase 1 deterministic cases (no AI): raw predictions through validator and executor |
| `datasets/phase_2_v1.json` | 68 | **Frozen** Phase 2 baseline. Never edited (a test checks a hash). The gate is applied here. |
| `datasets/phase_2_recovery_v1.json` | 48 | Development set: may be used to choose a prompt/configuration |
| `datasets/phase_2_recovery_heldout_v1.json` | 64 | Held-out, used in recovery round 1 |
| `datasets/phase_2_recovery_heldout_v2.json` | 64 | Held-out, used in round 2 (25% vague requests) |
| `datasets/phase_2_recovery_heldout_v3.json` | 64 | Held-out for round 3 (clarification flow), with expected clarification targets |

Every dataset has 4 languages in equal parts. No input appears in more than one dataset or in any prompt example (unit-tested).

## Rules that keep the numbers honest

1. **Expected results are fixed before inference** and never edited to match model output.
2. **Frozen** means byte-identical forever. New work uses new files.
3. A **held-out** set is run only after the configuration is final. Once used, it is burned: a new one is written for the next
   decision. The previous one stays as history.
4. **Development sets** are the only place to look at failures while choosing a prompt.
5. No rule, keyword or special case may target dataset inputs. The model does the interpreting.
6. Prompts are versioned (`promptVersion` in every result) and are immutable once run.

## Scoring definitions

* **Action correct:** the predicted action name equals the expected one (or both are "no action").
* **Parameters correct:** exactly the expected parameters. When neither the expectation nor the prediction is an action
  (a refusal or a question), correctness is the status.
* **Full prediction correct:** status, action and parameters all correct, no extra parameters, and for actions also
  accepted by the validator and executed.
* **Action accuracy:** over all cases. **Parameter accuracy:** over the cases that expect an action (so refusals do not
  inflate it).
* **Invalid output:** the model output could not become a valid prediction (for example several calls) or the validator
  rejected an action it proposed.
* **Fabricated parameter:** an argument the request does not support: any value for a request with no basis, an extra key,
  or a value outside the allowed enum. A wrong value inside the allowed set is `wrong_parameter`, not fabricated.
* **Prose output:** a text answer with no function call. A prose refusal on an expected-refusal case scores as correct; a
  stricter "prose counts as invalid" figure is reported next to it.
* **Asked the user (round 3):** the model called `ask_user`. Correct on vague requests (question or refusal both count);
  wrong on clear commands and on out-of-scope requests. The share asking the correct value is reported separately.
* **Failure categories** (one per failed case): `wrong_action`, `wrong_parameter`, `fabricated_parameter`,
  `unsupported_request_mapped_to_action`, `prose_output`, `multiple_function_calls`, `malformed_output`, `language_failure`,
  `mixed_language_failure`, `other`. Tags such as `navigate_profile_collapse` are additional, non-exclusive.

## The gate

Action accuracy >= 90%, parameter accuracy >= 90%, invalid outputs safely rejected 100%, uncontrolled execution 0. It was
defined on the frozen set. Later rounds also report an unseen held-out set, and the verdict rule for round 3 requires both.
