# Phase 2 recovery: larger local model

**Result: NOT READY FOR PHASE 3.** Gemma 4 E2B is far better than FunctionGemma 270M and passes the 90% gate on two of the three datasets, but it scores **88.2%** action accuracy on the frozen Phase 2 dataset, which is the dataset the gate was defined on. The gate was not lowered or reinterpreted.

## Baseline

FunctionGemma 270M, prompt `functiongemma_prompt_v1` (17 few-shot examples), exactly as in `docs/phase-2-evaluation.md`. It was re-run on all three datasets with the new scoring. Its outputs on the frozen set are byte-identical to the frozen baseline (68 of 68) and its metrics match (63.2% / 51.9% / 54.4%).

## Candidates

| Model | File | Size | Result on iOS Simulator |
|---|---|---:|---|
| Qwen3 0.6B (first preference) | `Qwen3-0.6B.litertlm` (dynamic INT8) | 614 MB | **Could not be evaluated: engine creation fails** |
| Gemma 4 E2B (selected) | `gemma-4-E2B-it.litertlm` | 2.59 GB | Loads and runs; evaluated |

**Qwen3 0.6B.** With `flutter_gemma` 1.11.3 / `flutter_gemma_litertlm` 1.8.5 (LiteRT-LM 0.17.1), `getActiveModel` fails with `Failed to create engine. Model may be invalid` after about 30 ms, on CPU. The file matched the published SHA-256, and the same failure occurred when the package downloaded it into the app's own storage, so it is not a path or corruption issue. The model card describes the build as targeting "Android and desktop deployment", not iOS. I did not find a cause beyond that (the native log was empty). I did not try the two other Qwen3 files (INT4 variants) and did not test Qwen3 on Android or macOS. **No accuracy was measured for Qwen3**, and any claim about it would be a guess. The downloaded files were deleted.

**Why Gemma 4 E2B.** Next in line among models the installed package lists as supporting function calling on iOS `.litertlm`. It uses the same native tool-call channel as FunctionGemma, so the adapter is unchanged. It is not a small model: 2.59 GB on disk, and its memory use was not measured.

## Runtime and configuration

* `flutter_gemma` 1.11.3, `flutter_gemma_litertlm` 1.8.5, LiteRT-LM 0.17.1, CPU backend.
* Gemma 4 E2B: `ModelType.gemma4`, `.litertlm`, `maxTokens` 4096, `maxOutputTokens` 256, `topK=1` (greedy), temperature 0.1, thinking off.
* **Prompt version `recovery_prompt_v1`** (the only version used; no tuning). Zero-shot, with the action list generated from the registered tools:

```
You translate the user's request into exactly one supported application action.

Available actions:
- change_theme
- navigate

Never invent actions.
Never invent parameter values.
Do not call an action when the user's intent is unclear.
If the request does not correspond to a supported action, do not produce an unrelated action.

Return a single structured function call when the request clearly maps to an available action.
```

* Tool schema: `change_theme(mode: light|dark|system)`, `navigate(destination: home|profile|settings)`, generated from the same enums the validator uses. The application contract and validator were not changed.
* Test device: iPhone 17 Pro Max **Simulator**, iOS 26.2, Apple-silicon Mac. No physical device. No Android.

## Datasets

| Dataset | Cases | Role |
|---|---:|---|
| `phase_2_v1.json` | 68 | Frozen baseline (unchanged; byte-identical, enforced by a test) |
| `phase_2_recovery_v1.json` | 48 | Development/tuning set (12 per language) |
| `phase_2_recovery_heldout_v1.json` | 64 | Held-out set (16 per language), run only after the configuration was fixed |

No input appears in more than one dataset (unit-tested). Expected results were written before any model ran.

**Process, honestly stated.** The dev set was run once on Gemma 4 E2B. It scored 91.7% action accuracy, above the gate, so the simplest prompt was kept and **no prompt tuning was done**. The final configuration was then run on all three sets in one session. The held-out and frozen sets therefore informed no decision. The final run was repeated once after fixing a result-file serializer bug (two diagnostic fields were missing from the per-case JSON); raw model outputs were identical to the first run for every case, on every dataset, for both models.

## Results

### Frozen Phase 2 dataset (68): the gate dataset

| Metric | FunctionGemma 270M | Gemma 4 E2B |
|---|---:|---:|
| Action accuracy | 63.2% | 88.2% |
| Parameter accuracy | 51.9% | 100.0% |
| Full prediction accuracy | 54.4% | 88.2% |
| Invalid output rate | 4.4% | 0.0% |
| Fabricated parameter rate | 8.8% | 11.8% |
| Multiple function call rate | 4.4% | 0.0% |
| Prose output rate | 23.5% | 11.8% |
| Full accuracy, prose counted as invalid (stricter) | 39.7% | 76.5% |
| `navigate(profile)` collapse (wrong results) | 21 of 68 | 0 of 68 |
| Uncontrolled executions | 0 | 0 |
| Invalid outputs executed | 0 | 0 |

| Language | FunctionGemma action | FunctionGemma params | FunctionGemma full | Gemma 4 action | Gemma 4 params | Gemma 4 full |
|---|---:|---:|---:|---:|---:|---:|
| English | 88.2% | 84.6% | 82.4% | 88.2% | 100.0% | 88.2% |
| MSA Arabic | 58.8% | 30.8% | 41.2% | 88.2% | 100.0% | 88.2% |
| Egyptian Arabic | 35.3% | 23.1% | 29.4% | 94.1% | 100.0% | 94.1% |
| Mixed Arabic/English | 70.6% | 69.2% | 64.7% | 82.4% | 100.0% | 82.4% |

### Development set (48)

| Metric | FunctionGemma 270M | Gemma 4 E2B |
|---|---:|---:|
| Action accuracy | 66.7% | 91.7% |
| Parameter accuracy | 55.6% | 100.0% |
| Full prediction accuracy | 58.3% | 91.7% |
| Invalid output rate | 6.2% | 0.0% |
| Fabricated parameter rate | 6.2% | 8.3% |
| Multiple function call rate | 6.2% | 0.0% |
| Prose output rate | 27.1% | 16.7% |
| Full accuracy, prose counted as invalid (stricter) | 41.7% | 75.0% |
| `navigate(profile)` collapse (wrong results) | 11 of 48 | 0 of 48 |
| Uncontrolled executions | 0 | 0 |
| Invalid outputs executed | 0 | 0 |

### Held-out set (64)

| Metric | FunctionGemma 270M | Gemma 4 E2B |
|---|---:|---:|
| Action accuracy | 70.3% | 90.6% |
| Parameter accuracy | 45.8% | 100.0% |
| Full prediction accuracy | 56.2% | 90.6% |
| Invalid output rate | 4.7% | 0.0% |
| Fabricated parameter rate | 3.1% | 9.4% |
| Multiple function call rate | 4.7% | 0.0% |
| Prose output rate | 31.2% | 15.6% |
| Full accuracy, prose counted as invalid (stricter) | 34.4% | 75.0% |
| `navigate(profile)` collapse (wrong results) | 15 of 64 | 0 of 64 |
| Uncontrolled executions | 0 | 0 |
| Invalid outputs executed | 0 | 0 |

| Language | FunctionGemma action | FunctionGemma params | FunctionGemma full | Gemma 4 action | Gemma 4 params | Gemma 4 full |
|---|---:|---:|---:|---:|---:|---:|
| English | 93.8% | 91.7% | 93.8% | 93.8% | 100.0% | 93.8% |
| MSA Arabic | 50.0% | 0.0% | 18.8% | 93.8% | 100.0% | 93.8% |
| Egyptian Arabic | 62.5% | 16.7% | 37.5% | 87.5% | 100.0% | 87.5% |
| Mixed Arabic/English | 75.0% | 75.0% | 75.0% | 87.5% | 100.0% | 87.5% |

### All three combined (180; informational, not the gate)

| Metric | FunctionGemma 270M | Gemma 4 E2B |
|---|---:|---:|
| Action accuracy | 66.7% | 90.0% |
| Parameter accuracy | 50.7% | 100.0% |
| Full prediction accuracy | 56.1% | 90.0% |
| Invalid output rate | 5.0% | 0.0% |
| Fabricated parameter rate | 6.1% | 10.0% |
| Multiple function call rate | 5.0% | 0.0% |
| Prose output rate | 27.2% | 14.4% |
| Full accuracy, prose counted as invalid (stricter) | 38.3% | 75.6% |
| `navigate(profile)` collapse (wrong results) | 47 of 180 | 0 of 180 |
| Uncontrolled executions | 0 | 0 |
| Invalid outputs executed | 0 | 0 |

| Language | FunctionGemma action | FunctionGemma params | FunctionGemma full | Gemma 4 action | Gemma 4 params | Gemma 4 full |
|---|---:|---:|---:|---:|---:|---:|
| English | 86.7% | 88.2% | 84.4% | 91.1% | 100.0% | 91.1% |
| MSA Arabic | 55.6% | 20.6% | 33.3% | 91.1% | 100.0% | 91.1% |
| Egyptian Arabic | 46.7% | 17.6% | 31.1% | 91.1% | 100.0% | 91.1% |
| Mixed Arabic/English | 77.8% | 76.5% | 75.6% | 86.7% | 100.0% | 86.7% |

## Gate

| Gate | Required | Gemma 4 E2B, frozen set | Held-out | Dev |
|---|---:|---:|---:|---:|
| Action accuracy | >= 90% | **88.2%** (fail) | 90.6% (pass, by 1 case) | 91.7% |
| Parameter accuracy | >= 90% | 100.0% | 100.0% | 100.0% |
| Invalid outputs safely rejected | 100% | 100% (invalid outputs: 0%, executed: 0) | 100% | 100% |
| Uncontrolled execution | 0% | 0 | 0 | 0 |

The gate was defined on the frozen Phase 2 dataset, so that is the one applied. **It fails: 60 of 68 correct (88.2%).** The held-out set passes by a single case (58 of 64, 90.6%), which is not a safe margin. Pooling all 180 cases gives 90.0%, again right at the line; that is not used to override the frozen result.

## Failure analysis

Primary failure categories, frozen dataset (like for like):

| Failure category (primary) | FunctionGemma | Gemma 4 |
|---|---:|---:|
| wrong_action | 10 | 0 |
| wrong_parameter | 6 | 0 |
| fabricated_parameter | 2 | 4 |
| unsupported_request_mapped_to_action | 4 | 4 |
| prose_output | 6 | 0 |
| multiple_function_calls | 3 | 0 |
| *tag:* `navigate(profile)` collapse | 21 | 0 |

All three datasets combined:

| Failure category (primary) | FunctionGemma | Gemma 4 |
|---|---:|---:|
| wrong_action | 23 | 0 |
| wrong_parameter | 19 | 0 |
| fabricated_parameter | 4 | 12 |
| unsupported_request_mapped_to_action | 7 | 6 |
| prose_output | 17 | 0 |
| multiple_function_calls | 9 | 0 |
| *tag:* `navigate(profile)` collapse | 47 | 0 |

What the data says:

* Every Gemma 4 failure is on a request that should **not** produce an action. No command with a clear intent failed in any language: parameter accuracy is 100% everywhere.
* **Vague requests** ("Change the theme", "غير الثيم", ...): all 12 (4 per dataset) were answered with `change_theme(mode=system)`, a value the user never gave.
* **Out-of-scope requests mapped to an action** (6 cases; they also count as fabricated because they carry made-up arguments, so the total fabricated count is 18 = 12 + 6): "Open Facebook" and "open الـFacebook" -> `navigate(home)`; "change the app language" (Arabic and mixed) -> `change_theme(light)`; "امسح حسابي" and "delete حسابي" -> `navigate(settings)`. The model chose the nearest available action instead of declining. The other out-of-scope requests (email, WhatsApp, money transfer, buying, calling, weather, notifications) were correctly declined.
* `navigate(profile)` collapse: 0 for Gemma 4 on the frozen set, against 21 for FunctionGemma.
* Prose: Gemma 4 declines in prose. A prose refusal on an expected-refusal case scores as correct (same as Phase 2). Counting prose as invalid gives 76.5% full accuracy on the frozen set; the verdict does not change.
* No multiple function calls and no malformed output from Gemma 4.

### Gemma 4 E2B failed cases (all datasets)

| ID | Input | Expected | Actual | Category | Explanation |
|---|---|---|---|---|---|
| unsupported-eng-001 | Open Facebook | unsupported | navigate(home) | unsupported_request_mapped_to_action | Request should not map to an exposed action but the model called navigate with {destination: home}. |
| clarify-eng-001 | Change the theme | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| clarify-msa-001 | غيّر المظهر | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| unsupported-msa-002 | غيّر لغة التطبيق إلى الإنجليزية | unsupported | change_theme(light) | unsupported_request_mapped_to_action | Request should not map to an exposed action but the model called change_theme with {mode: light}. |
| clarify-egy-001 | غير الثيم | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| unsupported-mix-001 | open الـFacebook | unsupported | navigate(home) | unsupported_request_mapped_to_action | Request should not map to an exposed action but the model called navigate with {destination: home}. |
| clarify-mix-001 | change الـtheme | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| unsupported-mix-003 | غير الـlanguage لـEnglish | unsupported | change_theme(light) | unsupported_request_mapped_to_action | Request should not map to an exposed action but the model called change_theme with {mode: light}. |
| v1-clarify-eng-001 | Switch the appearance | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| v1-clarify-msa-001 | بدّل مظهر التطبيق | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| v1-clarify-egy-001 | بدّل الثيم لو سمحت | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| v1-clarify-mix-001 | عدّل الـtheme | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| heldout_v1-clarify-eng-001 | Make the app look different | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| heldout_v1-clarify-msa-001 | غيّر شكل التطبيق | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| heldout_v1-unsupported-egy-003 | امسح حسابي | unsupported | navigate(settings) | unsupported_request_mapped_to_action | Request should not map to an exposed action but the model called navigate with {destination: settings}. |
| heldout_v1-clarify-egy-001 | غيّر شكل التطبيق شوية | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |
| heldout_v1-unsupported-mix-002 | delete حسابي | unsupported | navigate(settings) | unsupported_request_mapped_to_action | Request should not map to an exposed action but the model called navigate with {destination: settings}. |
| heldout_v1-clarify-mix-001 | غير الـlook بتاع الـapp | clarification_required | change_theme(system) | fabricated_parameter | Required value was missing from the request but the model called change_theme with {mode: system}. |

## Performance (CPU, iOS Simulator; not part of the gate)

| | FunctionGemma 270M | Gemma 4 E2B |
|---|---:|---:|
| Model file | 284 MB | 2.59 GB |
| Model loading (engine creation, file on disk) | 1035 ms | 5998 ms |
| First inference | 1341 ms | 1954 ms |
| Average subsequent inference | 1593 ms | 1914 ms |

Memory was **not measured**. Simulator latency is not representative of a phone. In the live demo the first command after loading took 4.2 s (warm-up) and later ones about 2 s.

## Safety (unchanged and re-verified)

* Pipeline: model -> adapter -> `ActionPrediction` -> validator -> `ActionRegistry.phase2()` -> executor. The model has no reference to application code.
* Across all runs (both models, 180 cases each): **0 uncontrolled executions, 0 invalid outputs executed.**
* Multiple function calls are rejected as malformed (never "first call wins"); prose becomes "no action" and is never parsed; unknown or non-exposed actions, bad enums, missing and extra parameters are rejected by the unchanged validator. Unit tests cover all of these; the full suite (141 tests, including the 131 from Phases 1 and 2) passes.
* **What validation cannot catch:** a legal-looking but wrong action. Gemma 4 executed `change_theme(system)` for vague requests and `navigate(settings)` for "delete my account". These pass validation because the values are legal. They are mistakes, not safety violations, and they are the reason the gate fails.

## Conclusion

1. **Did the larger model improve the baseline?** Yes, substantially. Frozen set: action 63.2% -> 88.2%, parameters 51.9% -> 100.0%, full 54.4% -> 88.2%.
2. **>= 90% action accuracy?** Not on the frozen set (88.2%). Yes on the dev set (91.7%) and the held-out set (90.6%, by one case).
3. **>= 90% parameter accuracy?** Yes: 100.0% on every dataset.
4. **Did Arabic improve?** Yes. MSA Arabic action accuracy on the frozen set: 58.8% -> 88.2%.
5. **Did Egyptian Arabic improve?** Yes, the most: 35.3% -> 94.1% on the frozen set.
6. **Did the misrouted-action rate decrease?** For commands with a clear intent, yes: the `navigate(profile)` collapse went from 21 cases to 0. For vague and out-of-scope requests, no: 18 fabricated-parameter cases across the 180 (12 vague requests that got a guessed value plus 6 out-of-scope requests mapped to an action). The fabricated-parameter rate on the frozen set is actually higher than FunctionGemma's (11.8% vs 8.8%), because FunctionGemma more often failed in other ways first.
7. **Did safety remain intact?** Yes: 0 uncontrolled executions.
8. **Is Phase 3 unblocked?** **No.** The frozen-set gate is 88.2%, below 90%.

## Next evidence-based experiment

The remaining failures are all "should do nothing" cases, not understanding failures. One experiment follows from the data, and it must not be tuned against the individual failures above:

* **Prompt version 2 aimed at abstention** (for example: a theme or destination the user did not name must not be guessed, and capabilities the app lacks, such as deleting an account, must not be mapped to the nearest action). Evaluate it on a **new** held-out set, because the current one has been used, and report it next to the unchanged `recovery_prompt_v1` results.
* Decide whether vague and out-of-scope requests belong in the Phase 2 gate. Those behaviours are the subject of Phase 4 (ambiguity and unknown requests). That is your decision; the gate was not changed.
* Separately from accuracy: the model is 2.59 GB, so memory and behaviour must be measured on a real phone before it is chosen. A smaller Qwen build remains untested.

## Reproducing

```bash
flutter test integration_test/phase_2_eval_test.dart -d <ios-simulator-id> \
  --dart-define=DEVICE_NAME="iPhone 17 Pro Max" --dart-define=DEVICE_KIND=simulator \
  --dart-define=MODEL=gemma4 --dart-define=PROMPT=recovery_prompt_v1 \
  --dart-define=DATASETS=phase_2_v1,phase_2_recovery_v1,phase_2_recovery_heldout_v1 \
  [--dart-define=MODEL_FILE=/abs/path/gemma-4-E2B-it.litertlm] | tee run.log
python3 tool/extract_eval_results.py run.log evaluation/results/gemma4_phase_2_v1.json result_phase_2_v1
python3 tool/make_recovery_doc.py   # regenerates this document from the result files
```

Results: `evaluation/results/{functiongemma,gemma4}_{phase_2_v1,phase_2_recovery_v1,phase_2_recovery_heldout_v1}.json`. The frozen baseline `evaluation/results/phase_2_v1.json` is unchanged. `evaluation/results/run1_before_serializer_fix/` holds the first runs (identical outputs).
