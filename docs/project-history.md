# Project history: every phase, step and decision

This is the chronological record of how the project was built, including the dead ends and mistakes. Numbers come from the
result files in `evaluation/results/` and are explained in the per-phase documents linked from `docs/README.md`.

**Goal.** Let a user give natural-language commands ("Turn on dark mode", "خلي التطبيق دارك", "روح على البروفايل") to a
Flutter app, using a small **on-device** model, while the application stays the only thing that validates and executes.

```
User input -> AI/interpreter -> structured action -> schema validation -> action registry -> risk policy -> execution
```

The AI only interprets. The application validates and executes. The project is strictly phase-gated: no phase starts until the
previous one passes its gate.

---

## Phase 1: deterministic action contract (no AI)

**Aim.** Prove the safe half of the pipeline before any model exists.

**Starting point.** An empty workspace, so a new Flutter app was created (Flutter 3.44.6, Dart 3.12.2) with a small isolated
`assistant` module and no extra dependencies except `flutter_localizations` (part of the SDK, for correct Arabic RTL).

**What was built** (`lib/assistant/`):

* `models/`: `ActionPrediction` (raw, untrusted, every field `Object?`; bad JSON never throws, it becomes a "malformed"
  prediction), typed `ActionParameters` and a strict `ParameterReader`.
* `actions/`: the five actions (`change_theme`, `change_language`, `navigate`, `toggle_notifications`, `search`), each a class
  with its own strict schema, and `ActionRegistry`, the single source of truth for what can run. Lookup is a map by exact name:
  no reflection, no `eval`, no callbacks from input.
* `validation/`: `ActionValidator` rejects malformed input, unexpected fields, unknown or missing status, unknown action,
  missing/null/wrong-type/out-of-enum/empty/too-long parameters and any **unexpected parameter** (strict policy: reject, never
  ignore or coerce). `status` is required.
* `execution/`: `ActionExecutor` re-resolves the action through the registry and refuses anything that is not the registered
  instance; `AssistantPipeline` is the only composition (executor reachable only from an accepted validation).
* `providers/`: the `AssistantModel` interface (`Future<ActionPrediction> interpret(String)`) and a `MockAssistantModel`.

**Policy decisions.** Unknown parameters reject the whole payload; navigation accepts only an enum (`home`, `profile`,
`settings`), never a route string; `search.query` is trimmed, non-empty, at most 200 characters; enum values are case-sensitive.

**Verification.** A deterministic dataset (`evaluation/phase_1_commands.json`, 47 cases) plus unit tests, including spy
objects proving that a rejected prediction never reaches the executor and never touches the app. 101 tests, all passing.
Results and the acceptance criteria: `docs/phase-1-evaluation.md`.

**Mistakes fixed on the way.** A test of "executor refuses an unregistered action" passed for the wrong reason because `const`
instances are canonicalised (the "foreign" action was identical to the registered one); the test now builds a non-const
instance. A widget test could not find its input because the default test surface left it off-screen.

---

## Phase 2: local AI (FunctionGemma 270M)

**Aim.** Measure whether a small on-device model can map natural language (English, MSA Arabic, Egyptian Arabic, mixed) to the
Phase 1 contract, restricted to two actions: `change_theme` and `navigate`.

**Verification of Phase 1 first.** The Phase 1 suite was re-run and passed before any AI code was written.

**Package research.** `flutter_gemma` 1.11.3 is modular: the core package registers no engine, so `flutter_gemma_litertlm` was
added (`.litertlm` format; LiteRT-LM 0.17.1). The first idea was `flutter_gemma_mediapipe` with a `.task` file, but the package
documents `.litertlm` as the recommended engine, it routes FunctionGemma through LiteRT-LM's **native tool-call channel**
(structured calls instead of text parsing), runs from iOS 15 and avoids the MediaPipe pod (iOS 16). FunctionGemma 270M
(`functiongemma-270M-it.litertlm`, 284 MB, public, no token) was chosen. Platform setup: iOS deployment target 15,
`UIFileSharingEnabled`, Android `minSdk 30` and the INTERNET permission (needed only to download the model once).

**Design.**

* The model sits behind the existing `AssistantModel` interface. `TracedAssistantModel.interpretWithTrace` also returns the raw
  output and latency (needed for evaluation).
* A `ModelOutputAdapter` converts the model's function call into an `ActionPrediction` and does **not repair anything**: names
  and values pass through exactly as the model said them, so the validator sees the truth. No function call means "no action"
  (prose is never parsed). Several calls are rejected as malformed (never "first call wins").
* `ActionRegistry.phase2()` contains only `change_theme` and `navigate`, so a model that names `change_language` (a real Phase 1
  action) is rejected by the validator.
* Tool definitions are generated from the same enums the validator uses, so the schema cannot drift.
* The prompt (`functiongemma_prompt_v1`) is the required short instruction plus 17 hand-picked few-shot examples. A unit test
  enforces that none of them appears in the evaluation dataset.

**Evaluation design** (`lib/assistant/evaluation/`, `integration_test/phase_2_eval_test.dart`). A fixed dataset
(`datasets/phase_2_v1.json`: 68 commands, 17 per language, including requests that must NOT become actions and vague ones),
expected results written before any inference. The runner takes each input through the real model, adapter, validator and
executor, and scores action, parameter and full-prediction accuracy, invalid-output rate, fabricated-parameter rate, latency, with
failure categories. Because the model needs a phone or simulator, the runner is an integration test that prints its result as
base64 chunks; `tool/extract_eval_results.py` rebuilds the JSON on the host.

**Result (iOS Simulator, CPU).** Action accuracy 63.2%, parameter accuracy 51.9%, full prediction 54.4%; English 88%, MSA 59%,
Egyptian 35%, mixed 71%. 28 of 68 outputs collapsed to `navigate(profile)`, 6 Arabic commands got prose, 3 got several calls.
Safety: 0 uncontrolled executions. **Gate (>= 90%) failed.** Details: `docs/phase-2-evaluation.md`.

**Mistake fixed.** The first result files lacked two diagnostic fields because the serializer was patched with a text replace
that the formatter had silently defeated; the evaluation was re-run and produced byte-identical outputs (deterministic greedy
decoding), so the numbers did not change.

Phase 3 (more actions) was **blocked** because Phase 2 did not meet its gate.

---

## Phase 2 recovery, round 1: a larger model

**Aim.** Same architecture, same contract, a larger local model. Baseline frozen (`phase_2_v1.json` and its result are
byte-identical forever; a test checks their hash). A development set (48) and a held-out set (64) were written before any run.

**Refactor for comparability.** The runtime became configuration-driven so models could be swapped without touching anything
else; prompts became versioned objects; the evaluator gained multiple-call, prose and `navigate(profile)`-collapse metrics.

**Candidate 1: Qwen3 0.6B** (`Qwen3-0.6B.litertlm`, 614 MB). It failed to load on the iOS Simulator
(`Failed to create engine. Model may be invalid`, after about 30 ms). The first attempt used a truncated 68 MB file (a download
that "completed" with exit 0), then the correct file (SHA-256 verified) failed the same way, and so did the package's own
download into the app's storage, so it is not a path or corruption issue. The model card says the build targets Android and
desktop. No accuracy was measured. The files were deleted.

**Candidate 2: Gemma 4 E2B** (`gemma-4-E2B-it.litertlm`, 2.59 GB). It loads and runs. With the simplest prompt
(`recovery_prompt_v1`, zero-shot, no tuning) it scored 88.2% action / 100% parameters on the frozen set (FunctionGemma: 63.2% /
51.9%), 91.7% on the development set and 90.6% on the held-out set. Egyptian Arabic went from 35% to 94% on the frozen set;
the `navigate(profile)` collapse went from 21 cases to 0. **Every failure was a request that should not produce an action**:
12 vague requests answered with a guessed `change_theme(system)` and 6 out-of-scope requests mapped to the nearest action.
Gate: not met on the frozen set (88.2% < 90%). Details: `docs/phase-2-recovery.md`, comparison table:
`docs/model-comparison.md`.

**Operational notes.** A 2.6 GB download stalled for over 15 minutes at 2.25 GB without failing (curl kept waiting). The fix is
resumable downloads with a stall detector. macOS has no `timeout` command, so a retry loop that used it never ran curl; this was
noticed because the file size never changed.

---

## Round 2: can the prompt fix guessing?

**Question.** Does telling the model "never guess a value the user did not state" (prompt v2), plus negative examples (v3),
stop it from guessing?

**Procedure** (written before running, see `docs/phase-2-recovery-round2.md`): choose v2 or v3 on the development set by a
pre-declared rule, run the chosen prompt once on the frozen set and on a NEW held-out set (v2, 64 cases, 25% vague), with the
unchanged prompt as control.

**Result.** v2 and v3 scored exactly like v1 on the development set, so v2 (simpler) was chosen. On the frozen set v2 reached
91.2% action accuracy (62 of 68) only because two "change the language" requests that v1 mapped to `change_theme(light)` were now
declined. On the unseen held-out v2 both prompts scored 73.4%: all 16 vague requests were guessed (theme requests became
`change_theme(system)`, page requests became `navigate(home)`), while clear commands (31 of 32) and out-of-scope requests
(16 of 16) were handled well. **Prompt wording did not make the model abstain.** Verdict: not ready.

---

## Interface and architecture work

**First demo UI.** A single screen with a natural-language box, a Phase 1 raw-JSON tester and a trace (input, model output,
prediction, validation, execution). It was driven live on the simulator. Findings: typing from the test tooling does not reach
Flutter text fields, so sample phrases became tappable chips; a vague request ("Switch the appearance") visibly changed the
theme to `system`, a guessed value that passed validation.

**Redesign (round 3 work).** The UI became a real app: Home, Profile and Settings pages, an assistant dock with a model status
banner and suggestion chips, a result card with an Understood / Checked / Done stepper and collapsible details, model picker,
Arabic with full RTL, dark mode, and a Developer page for the Phase 1 JSON tester. See `docs/ui-guide.md`.

**Separation.** The inference package is imported by exactly one file; model identities are data in `model_catalog.dart`;
tool definitions are generated from the action registry (each action declares its description and schema); the UI depends only
on abstractions. `test/architecture_test.dart` enforces this. See `docs/architecture.md`.

---

## Round 3: let the user decide (clarification flow)

Because wording could not stop the guessing, the interaction was redesigned: the model gets one extra function, `ask_user`,
meaning "the request refers to this action but does not say which value". The application turns the target into options from
its own enums, shows them to the user, and executes only the user's validated choice. Nothing runs before the user answers.

**Steps, in order.**

1. Wrote the protocol first (`docs/phase-2-recovery-round3.md`): prompt `clarify_prompt_v4`, at most one revision decided on the
   development set, final run once on the frozen set and a new held-out set (v3, written before any run), and the verdict rule
   (READY only if the frozen set and the unseen held-out set both pass for the same model and prompt).
2. Implemented the contract: each action now declares its description, parameter schema and clarifiable parameters; the registry
   generates the tool definitions (and the optional `ask_user`), resolves a target into options, and the pipeline turns a user's
   answer into an ordinary prediction that goes through the validator. 27 new unit tests cover malicious or invalid targets, the
   model trying to add options or pick a value, and out-of-offer choices.
3. Refactored for separation: model identities became data (`model_catalog.dart`), the runtime became config-driven and the only file
   importing the inference package, `test/architecture_test.dart` enforces the layering. FunctionGemma was re-run and reproduced the
   frozen outputs byte for byte (68 of 68).
4. Rebuilt the UI (pages, assistant dock, result card with stepper, question card, model picker, RTL, dark mode, developer tools).
5. On-device runs: the E2B model file was lost when the session's temporary folder was reset, so the work moved to **Gemma 4 E4B**
   (3.66 GB, downloaded with a resumable script and SHA-256 verified). Development set: 100% / 100% / 100%, all four vague requests
   answered with a question. Final run: frozen set 100% / 100% / 97.1%, held-out v3 100% / 100% / 100% (16 of 16 vague requests asked,
   15 about the right value). Control (same E4B, no question function): 79.7% on held-out v3, 13 of 16 vague requests guessed.
6. Drove the real model in the app: "Change the theme" produced "Which theme do you want?" with the registered options; choosing Dark
   executed it.
7. Replaced the harness's blank "Test starting..." screen with a live progress screen (stages, current command, model output,
   running accuracy, safety counter). A first version could not be scrolled because the live test binding ignores device touches by
   default; fixed with `shouldPropagateDevicePointerEvents`, an auto-follow to the active dataset and a collapsed quick-check card.

**Result.** The gate is met for Gemma 4 E4B + `clarify_prompt_v4` on both datasets; the verdict under the pre-declared rule is
READY FOR PHASE 3. Not measured: memory, real devices, Gemma 4 E2B with the question flow.

**Mistakes and fixes along the way.** A formatter silently defeated two scripted edits (result fields missing from the JSON, and a
test insertion that did not land); both were caught by checking and re-done. `timeout` does not exist on macOS, so a retry loop never
ran its command. A simulator shut down on its own and a test run failed with "No devices are connected"; it was re-booted and re-run.

---

## Where things stand

See the "Status" section of the root `README.md` and `docs/phase-2-recovery-round3.md` for the latest numbers and verdict. Phase 2's
gate is met by Gemma 4 E4B with the clarification flow. Phases 3 to 9 have **not** been started: Phase 3 (adding `change_language`,
`toggle_notifications`, `search` one at a time with regression checks) is the next step but needs your go-ahead, and the model's
size, speed and memory on a real phone should be checked first.

## Lessons

* Measure on data the prompt has never seen. The frozen-set improvement in round 2 (88.2% to 91.2%) was two cases of wording
  luck; the unseen set showed no effect.
* A validator makes the app safe, not right. A legal but wrong action still executes; design the interaction so the user
  decides when intent is unclear.
* Verify downloads by size and checksum. A truncated model file fails with a generic error.
* Keep results reproducible: greedy decoding, versioned prompts, frozen datasets with hash tests, raw outputs in every result file.
* Text replacements in scripted edits can silently not apply after auto-formatting; check the result.
