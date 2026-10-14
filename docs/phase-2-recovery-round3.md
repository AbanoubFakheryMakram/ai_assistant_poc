# Phase 2 recovery, round 3: let the user decide (clarification flow)

Status: **complete.** The protocol was written before any round-3 run; results follow it.

## Why

Rounds 1 and 2 (`docs/phase-2-recovery.md`, `docs/phase-2-recovery-round2.md`) showed that Gemma 4 E2B understands clear
commands in all four languages (100% parameter accuracy), but **guesses a value when the user did not give one**:
"Change the theme" became `change_theme(system)`, "Open a page" became `navigate(home)`. Telling the model "do not
guess" in the prompt (v2) and showing it negative examples (v3) did not change that (0 of 16 vague requests handled
on unseen data).

The cause is structural: the only way the model could "not guess" was to say nothing, and it almost never did. Round 3
changes the **interaction design** instead of the wording:

* The model is given one more function, `ask_user(target)`, generated from the registry. It means "the request clearly
  refers to this action but does not say which value". It cannot execute anything and carries no value.
* The **application** turns the target into options taken from its own enums (`light/dark/system`,
  `home/profile/settings`) and shows them to the user. The model neither writes the options nor chooses among them.
* The user's choice is converted into an ordinary prediction and goes through the same validator, registry and executor
  as any other action. Nothing runs before the user answers.
* Requests the app cannot do (no function call) get a fixed "I can't do that" message. The model's own text is not shown.

## What was built

| Piece | Where |
|---|---|
| `ClarifiableParameter`, `ClarificationOffer` | `lib/assistant/actions/clarification.dart` |
| Each action declares its description, parameter schema and clarifiable parameters | `lib/assistant/actions/*_action.dart` |
| `ActionRegistry.toolSpecs(allowClarification:)`, `offerFor(target)` | `lib/assistant/actions/action_registry.dart` |
| `ask_user` -> `clarification_required` prediction (target kept raw) | `lib/assistant/providers/model_output_adapter.dart` |
| Options from the registry, `resolveClarification` through validation | `lib/assistant/execution/assistant_pipeline.dart` |
| Prompt `clarify_prompt_v4` | `lib/assistant/providers/model_prompt.dart` |
| New metrics: asked-the-user rate on vague requests, correct target, over-asking | `lib/assistant/evaluation/evaluator.dart` |
| UI: question card with the registry's options, "None of these" | `lib/app/assistant/turn_card.dart` |

Safety properties (unit-tested in `test/assistant/execution/clarification_test.dart`): an unknown or non-allowed target
produces no options; the model cannot add options or pick a value; a user choice outside the offer is rejected by the
validator; the executor is not called before the user answers.

## Prompt version

`clarify_prompt_v4`, zero-shot (the action list is generated from the exposed tools, and the `ask_user` paragraph is
only included when that function is exposed):

```
You translate the user's request into exactly one supported application action.

Available actions:
- change_theme
- navigate

Never invent actions.
Never invent parameter values.

If the request clearly refers to one of the actions but does not say which value to use (for example which theme, or
which page), call ask_user with the missing item. Do not guess the value.
If the request is something the available actions cannot do, answer without calling any function.
Otherwise, return a single structured function call.
```

## Datasets

| Dataset | Role |
|---|---|
| `phase_2_recovery_v1.json` (48) | Development set. Used to check that the new function is used correctly. |
| `phase_2_v1.json` (68) | Frozen set. Gate applied here. |
| `phase_2_recovery_heldout_v3.json` (64) | **New** held-out set (SHA-256 `e2aebe3b805083eb2e9699b1ecc72ded12142c68d71d512f77359ea44612a13a`), written before any round-3 run. 16 per language, 25% each: theme, navigate, out-of-scope, vague. Each vague case records the expected clarification target. No input overlaps any earlier dataset or any prompt example (unit-tested). |
| `phase_2_recovery_heldout_v2.json` (64) | Used in round 2; not used to choose anything in round 3. |

## Procedure (declared before running)

1. Run `clarify_prompt_v4` with the `ask_user` function on the **development set**, Gemma 4 E2B. Inspect failures **on
   the development set only**.
2. **At most one revision** of the prompt (`v5`), allowed only if the development set shows the new function being
   misused in a way a wording fix could address; it is decided on the development set alone and recorded. Otherwise v4 is final.
3. Freeze the prompt. Run it once on the frozen set and on held-out v3, for Gemma 4 E2B and Gemma 4 E4B. Run round 2's
   `recovery_prompt_v2` (no question function) on held-out v3 for Gemma 4 E2B as the control.
4. New questions measured: share of vague requests answered with a question; share asking about the correct value;
   share of requests that should NOT be questions (clear commands, out-of-scope requests) answered with a question
   (over-asking); regressions on clear commands.
5. **Gate** (unchanged numbers): action accuracy >= 90%, parameter accuracy >= 90%, invalid output safely rejected 100%,
   uncontrolled execution 0. **Verdict rule, declared now:** READY only if the frozen set AND the unseen held-out v3
   both meet the thresholds for the same model and prompt. A pass on one and not the other is NOT READY.
6. Scoring of a vague request: a question or a refusal both count as correct (as before); a guessed value is wrong.
   Asking where the request should be declined (for example "set an alarm") is wrong.

## Results

Model for all round-3 numbers: **Gemma 4 E4B** (`gemma-4-E4B-it.litertlm`, 3.49 GB), `clarify_prompt_v4` with the `ask_user`
function, CPU, iPhone 17 Pro Max Simulator, iOS 26.2, `topK=1`. Format: action / parameters / full-prediction accuracy.

### Deviations from the protocol (declared before running, all forced by the same event)

The Gemma 4 E2B model file was lost when the session's temporary folder was reset, so step 1 and step 3 could not use it. I
used **Gemma 4 E4B** (the model you asked to try) for step 1 and for the final run, and replaced the E2B control with an **E4B
control** (`recovery_prompt_v2`, no question function) on the same held-out v3. **Gemma 4 E2B with `clarify_prompt_v4` was not
run.** The step order, the "at most one revision" rule and the verdict rule were unchanged.

### Step 1: development set (48), E4B + v4

| | Result |
|---|---|
| Action / parameters / full | 100.0% / 100.0% / 100.0% |
| Vague requests answered with a question | 4 of 4 (one per language) |
| Asked where it should not | 0 |
| Fabricated-parameter rate | 0.0% |
| Uncontrolled executions | 0 |

The new function was used correctly (`ask_user(change_theme.mode)` for all four vague theme requests), so **no prompt revision was made;
v4 is final**.

### Step 3: frozen set (68) and the unseen held-out v3 (64)

| | Frozen (68) | Held-out v3 (64, unseen) |
|---|---|---|
| E4B + v4: action / parameters / full | 100.0% / 100.0% / 97.1% | 100.0% / 100.0% / 100.0% |
| Invalid output rate | 0.0% | 0.0% |
| Fabricated-parameter rate | 0.0% | 0.0% |
| Vague requests answered with a question | 4 of 4 | 16 of 16 |
| Questions about the correct value | n/a (target not recorded in this dataset) | 15 of 16 |
| Asked where it should have declined | 2 | 0 |
| Uncontrolled executions | 0 | 0 |
| Invalid outputs executed | 0 | 0 |
| Avg inference latency | 4919 ms (min 3817, max 12265) | 4208 ms (min 3608, max 17209) |

Held-out v3 by kind of request (E4B + v4): {'theme': '16/16', 'navigate': '16/16', 'out-of-scope': '16/16', 'vague': '16/16'}.

**Control: the same E4B without the question function** (`recovery_prompt_v2`) on held-out v3:

| | E4B + v2 (no question) | E4B + v4 (question) |
|---|---|---|
| Action / parameters / full | 79.7% / 100.0% / 79.7% | 100.0% / 100.0% / 100.0% |
| Fabricated-parameter rate | 20.3% | 0.0% |
| By kind | {'theme': '16/16', 'navigate': '16/16', 'out-of-scope': '16/16', 'vague': '3/16'} | {'theme': '16/16', 'navigate': '16/16', 'out-of-scope': '16/16', 'vague': '16/16'} |

For context (round 2, Gemma 4 E2B, frozen set): v1 88.2%, v2 91.2% action accuracy.

Language breakdown, held-out v3 (E4B + v4):

| Language | Cases | Action | Parameters | Full |
|---|---:|---:|---:|---:|
| English | 16 | 100.0% | 100.0% | 100.0% |
| MSA Arabic | 16 | 100.0% | 100.0% | 100.0% |
| Egyptian Arabic | 16 | 100.0% | 100.0% | 100.0% |
| Mixed Arabic/English | 16 | 100.0% | 100.0% | 100.0% |

Language breakdown, frozen set (E4B + v4):

| Language | Cases | Action | Parameters | Full |
|---|---:|---:|---:|---:|
| English | 17 | 100.0% | 100.0% | 94.1% |
| MSA Arabic | 17 | 100.0% | 100.0% | 100.0% |
| Egyptian Arabic | 17 | 100.0% | 100.0% | 100.0% |
| Mixed Arabic/English | 17 | 100.0% | 100.0% | 94.1% |

### Failures

Frozen set (E4B + v4), every non-fully-correct case:

| ID | Input | Expected | Model output | Category |
|---|---|---|---|---|
| unsupported-eng-001 | Open Facebook | unsupported | call ask_user({target: navigate.destination}) | other |
| unsupported-mix-001 | open الـFacebook | unsupported | call ask_user({target: navigate.destination}) | other |

Held-out v3 (E4B + v4): no fully-incorrect cases. One question asked about the wrong value: 'غيّر الـview' -> asked `navigate.destination`, expected `change_theme.mode` (the user still sees real options and "None of these"; nothing runs).

Reading the frozen failures: for "Open Facebook" and "open الـFacebook" the model called `ask_user(navigate.destination)` instead
of declining. Nothing was executed; the user would have been asked which of home / profile / settings they meant for a request
the app cannot do. It counts as wrong (a question where a refusal was expected), it is not a safety violation, and it is the
only kind of mistake left.

## Gate and verdict

| Gate | Required | Frozen (E4B + v4) | Held-out v3 (E4B + v4) |
|---|---:|---:|---:|
| Action accuracy | >= 90% | 100.0% | 100.0% |
| Parameter accuracy | >= 90% | 100.0% | 100.0% |
| Invalid output safely rejected | 100% | 100% | 100% |
| Uncontrolled execution | 0 | 0 | 0 |

**Verdict under the rule declared before running: READY FOR PHASE 3** (Phase 2 gate met for Gemma 4 E4B with `clarify_prompt_v4`
on both the frozen set and the unseen held-out set). Phase 3 itself has not been started.

What this verdict does and does not say:

* The model **is large**: 3.49 GB on disk, about 33.3 s to load and about 4 to 6 s per command on average on a simulator CPU
  (maximum 19 s). Memory was **not measured**. Nothing was run on a physical iPhone or on Android. The gate in this
  project is about accuracy and safety, not size or speed, so it does not cover these.
* The control shows that **the interaction design, not the model size, fixed the guessing**: the same E4B scored
  79.7% without the question function.
* Whether the smaller Gemma 4 E2B reaches the same numbers with `ask_user` is **untested**.
* The datasets are small (a case is 1.5 to 1.6 percentage points), the held-out set was written by the same person/assistant as the prompts, and
  the user-facing question flow was exercised manually with the real model on one request ("Change the theme" -> Dark) and in
  widget tests, not in a user study.

## Live demonstration (real model, new UI)

Gemma 4 E4B loaded in the app on the simulator. "Change the theme": the card showed Understood, Checked, then
**"Which theme do you want?"** with Light, Dark, System and None of these, while the Theme tile still said Light (nothing had run).
Tapping **Dark** completed the third step, showed "Theme set to dark", and the whole app switched to the dark theme.
