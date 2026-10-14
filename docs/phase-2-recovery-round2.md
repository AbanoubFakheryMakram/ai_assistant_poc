# Phase 2 recovery, round 2: abstention prompts on Gemma 4 E2B

Status: **complete.** The protocol below was written before any round-2 run; results follow it.

## Why

Round 1 (`docs/phase-2-recovery.md`) showed Gemma 4 E2B with `recovery_prompt_v1` reaching 100% parameter accuracy
and 88.2% action accuracy on the frozen Phase 2 set. Every failure was a request that should not produce an action:
12 vague requests answered with a guessed `change_theme(system)`, and 6 out-of-scope requests mapped to the closest
action. Round 2 tests whether prompt changes alone fix that. Model, runtime, backend, sampling, tools, validator and
action contract are unchanged. Gemma 4 E4B is deliberately not tried here.

## Prompt versions (immutable once run)

| Version | Content |
|---|---|
| `recovery_prompt_v1` | Round 1 prompt (already measured). |
| `recovery_prompt_v2` | v1 + "Never guess a parameter value the user did not state. If a value the action needs (for example which theme, or which page) is missing, do not call a function. If the user asks for something the available actions cannot do, do not call a function, and do not pick the closest available action instead." No examples. |
| `recovery_prompt_v3` | v2 + 10 negative examples (requests that must NOT call any function), in English, Arabic, Egyptian Arabic and mixed. |

The text is in `lib/assistant/providers/model_prompt.dart`. The negative examples were written by category (a capability
the app lacks; a missing value). **Disclosure:** I wrote them knowing which failure categories appeared in round 1, so
they are category-level hints, not a neutral prior. A unit test guarantees that no example appears in any dataset, so the
datasets measure whether the model generalizes to different wording of those categories.

## Datasets

| Dataset | Role in round 2 |
|---|---|
| `phase_2_recovery_v1.json` (48) | Development set. Used to choose between v2 and v3. |
| `phase_2_v1.json` (68) | Frozen Phase 2 set; the gate is applied here. Run once, with the chosen prompt. |
| `phase_2_recovery_heldout_v2.json` (64) | **New** held-out set (SHA-256 `ebfdf22a219916ec78b0c7d5f331e1a1fb9dc5f8df75b780f20e9b57757c37e9`). 16 per language, 25% each: theme, navigate, out-of-scope, vague. Includes vague `navigate` requests ("Open a page"), which earlier sets lacked, and out-of-scope requests for real app capabilities that are not exposed (change language, turn off notifications). Run once, after the prompt is chosen. |
| `phase_2_recovery_heldout_v1.json` (64) | Already used in round 1. Not used to choose anything in round 2. |

No input appears in more than one dataset or in any prompt example (unit-tested).

## Procedure (declared before running)

1. Run v2 and v3 on the **development set** only.
2. **Selection rule:** choose the prompt with the higher full-prediction accuracy on the development set; if tied,
   choose v2 (simpler). No other criterion, and the held-out v2 set is not run before this choice.
3. Run the chosen prompt once on the frozen set and on held-out v2. Run `recovery_prompt_v1` on held-out v2 as the
   control, so the comparison is on identical, previously unseen data.
4. No prompt edits after step 1. Report all results, including a regression on positive commands (over-refusal), which
   would show as lower action or parameter accuracy on the expected-success cases.
5. Gate unchanged: action >= 90%, parameters >= 90%, invalid output safely rejected 100%, uncontrolled execution 0, on
   the frozen set.

## Results

All runs: Gemma 4 E2B, same file, CPU, iPhone 17 Pro Max Simulator, iOS 26.2, `topK=1`. Raw outputs are deterministic.
Format: action / parameters / full prediction accuracy.

### Step 1: development set (48), v1 vs v2 vs v3

| | v1 (round 1) | v2 (rule) | v3 (rule + negative examples) |
|---|---|---|---|
| Development set | 91.7% / 100.0% / 91.7% | 91.7% / 100.0% / 91.7% | 91.7% / 100.0% / 91.7% |
| Fabricated parameter rate | 8.3% | 8.3% | 8.3% |
| Avg inference latency (CPU) | 1917 ms | 2207 ms | 2435 ms |

* v2 and v3 scored **exactly the same as v1**: the same 4 vague requests (one per language) were still answered with a guessed `change_theme(mode=system)`.
* The prompts did reach the model: refusal wording changed (4 outputs differ between v1 and v2, 7 between v1 and v3) and latency grows with prompt length. They just did not change the decision on the cases that failed.
* **Selection by the pre-declared rule:** v2, v3 and v1 tie on full accuracy, so v2 is chosen (tie goes to the simpler prompt). The negative examples (v3) added nothing measurable and cost about 230 ms per command.

### Step 2: frozen Phase 2 set (68), chosen prompt v2 vs v1

| | v1 | v2 |
|---|---|---|
| Frozen Phase 2 set (68) | 88.2% / 100.0% / 88.2% | 91.2% / 100.0% / 91.2% |
| Fabricated parameter rate | 11.8% | 8.8% |
| Uncontrolled executions | 0 | 0 |

v2 changed 7 outputs (wording) and flipped **two results from wrong to right**: "غيّر لغة التطبيق إلى الإنجليزية" and "غير الـlanguage لـEnglish" were mapped to `change_theme(light)` by v1 and are now declined. Nothing regressed (60 correct -> 62 correct of 68). Remaining failures (6):

| ID | Input | Expected | Actual | Category |
|---|---|---|---|---|
| unsupported-eng-001 | Open Facebook | unsupported | navigate(home) | unsupported_request_mapped_to_action |
| clarify-eng-001 | Change the theme | clarification_required | change_theme(system) | fabricated_parameter |
| clarify-msa-001 | غيّر المظهر | clarification_required | change_theme(system) | fabricated_parameter |
| clarify-egy-001 | غير الثيم | clarification_required | change_theme(system) | fabricated_parameter |
| unsupported-mix-001 | open الـFacebook | unsupported | navigate(home) | unsupported_request_mapped_to_action |
| clarify-mix-001 | change الـtheme | clarification_required | change_theme(system) | fabricated_parameter |

### Step 3: new held-out v2 (64, never seen before this run), v2 vs v1 control

| | v1 (control) | v2 |
|---|---|---|
| Held-out v2 (64) | 73.4% / 96.9% / 73.4% | 73.4% / 96.9% / 73.4% |
| Fabricated parameter rate | 25.0% | 25.0% |
| Uncontrolled executions | 0 | 0 |

By kind of request (full-prediction correct), identical for both prompts:

| Kind | Cases | Correct |
|---|---:|---:|
| Theme change | 16 | 15 |
| Navigate | 16 | 16 |
| Out-of-scope (alarm, music, change language to French, turn off notifications) | 16 | 16 |
| **Vague (missing value)** | 16 | **0** |

* **v2 had no effect on held-out v2.** 50 of 64 raw outputs are identical and the scoring is identical. Even the v1 control declined all 16 out-of-scope requests, including "change the language", so the frozen-set improvement is not evidence of a general prompt effect. It is two cases where the two prompts happen to word a refusal differently.
* **The explicit rule "never guess a value the user did not state" did not make the model abstain on vague requests.** All 16 failed in all four languages: vague theme requests became `change_theme(system)`, vague navigate requests ("Open a page", "Take me somewhere else", "افتح صفحة") became `navigate(home)`.
* One real error on a clear command: "عايزه فاتح" -> `navigate(home)` (both prompts).
* Without the vague requests, the other 48 cases are 47 correct (97.9%). Vague requests are the subject of Phase 4 (ambiguity), but the gate has not been redefined here.

Failures on held-out v2 (v2 prompt; v1 identical):

| ID | Input | Expected | Actual | Category |
|---|---|---|---|---|
| vague-eng-001 | Change the colors | clarification_required | change_theme(system) | fabricated_parameter |
| vague-eng-002 | Switch the theme | clarification_required | change_theme(system) | fabricated_parameter |
| vague-eng-003 | Take me somewhere else | clarification_required | navigate(home) | fabricated_parameter |
| vague-eng-004 | Open a page | clarification_required | navigate(home) | fabricated_parameter |
| vague-msa-001 | غيّر الألوان | clarification_required | change_theme(system) | fabricated_parameter |
| vague-msa-002 | بدّل السمة | clarification_required | change_theme(system) | fabricated_parameter |
| vague-msa-003 | خذني إلى مكان آخر | clarification_required | navigate(home) | fabricated_parameter |
| vague-msa-004 | افتح صفحة | clarification_required | navigate(home) | fabricated_parameter |
| theme-egy-002 | عايزه فاتح | change_theme(light) | navigate(home) | wrong_action |
| vague-egy-001 | غيّرلي الألوان | clarification_required | change_theme(system) | fabricated_parameter |
| vague-egy-002 | عدّل الشكل | clarification_required | change_theme(system) | fabricated_parameter |
| vague-egy-003 | وديني في حتة تانية | clarification_required | navigate(home) | fabricated_parameter |
| vague-egy-004 | افتحلي صفحة | clarification_required | navigate(home) | fabricated_parameter |
| vague-mix-001 | غيّر الـcolors | clarification_required | change_theme(system) | fabricated_parameter |
| vague-mix-002 | بدّل الـtheme | clarification_required | change_theme(system) | fabricated_parameter |
| vague-mix-003 | خدني في مكان تاني | clarification_required | navigate(home) | fabricated_parameter |
| vague-mix-004 | open صفحة | clarification_required | navigate(home) | fabricated_parameter |

## Gate

| Gate | Required | Frozen set (v2 prompt) | Held-out v2 (unseen) |
|---|---:|---:|---:|
| Action accuracy | >= 90% | **91.2%** (62 of 68; passes by one case) | **73.4%** (fails) |
| Parameter accuracy | >= 90% | 100.0% | 96.9% |
| Invalid outputs safely rejected | 100% | 100% | 100% |
| Uncontrolled execution | 0 | 0 | 0 |

## Conclusion

* **Did the prompt change work?** Not in the way intended. The explicit rule and the negative examples did not change the model's behaviour on vague requests (0 of 16 on unseen data, unchanged from v1). The one visible gain, two out-of-scope "change language" requests on the frozen set, does not reproduce as an advantage on held-out v2.
* **Literal gate result on the frozen set: met** (91.2% action, 100% parameters, 0 uncontrolled executions), by a margin of a single case. On the unseen held-out v2 the same thresholds are **not** met (73.4%).
* **Verdict: NOT READY FOR PHASE 3.** The gate exists to certify that the model behaves reliably; the one unbiased measurement taken in this round fails the same thresholds, the frozen-set pass is one case and is not backed by a measured prompt effect, and the failing category (vague requests) is the one the prompt was meant to fix and did not. If you decide the frozen set alone defines the gate, the literal numbers pass; that is your call and I have not changed the gate.
* **Safety** stayed intact in every run of this round: 0 uncontrolled executions, 0 invalid outputs executed.

## What the evidence points to next

Prompt wording alone (rule, examples) does not make this model abstain on missing values. Options that are not prompt-only, each of which needs its own unseen evaluation:

1. **Application-side handling of the missing value.** The contract currently forces a value. Phase 4 (ambiguity) would let the app ask "which theme?" instead of trusting the model; that is outside Phase 2's scope and I did not implement it.
2. **A larger sibling (Gemma 4 E4B, about 4.3 GB per the package README):** untested and heavier; you asked not to try it in this round.
3. **Fine-tuning on abstention examples.** Highest effort.

## Reproducing round 2

```bash
flutter test integration_test/phase_2_eval_test.dart -d <ios-simulator-id> \
  --dart-define=MODEL=gemma4 --dart-define=PROMPT=recovery_prompt_v2 \
  --dart-define=DATASETS=phase_2_v1,phase_2_recovery_heldout_v2 \
  --dart-define=MODEL_FILE=/abs/path/gemma-4-E2B-it.litertlm | tee run.log
```

Results: `evaluation/results/gemma4_recovery_prompt_v{1,2,3}_*.json`. Unit tests (144, all passing) check the prompt versions, that held-out v2 overlaps no dataset and no prompt example, and that the frozen files are byte-identical.
