# User interface guide

The app is a small demo whose purpose is to show the assistant working safely. Everything the user sees is localized in
English and Arabic (`lib/app/strings.dart`), and the `change_language` action flips the whole UI including text direction.

## Pages

| Page | What it shows |
|---|---|
| **Home** | Gradient header, four state tiles (theme, language, notifications, page), last search, and sample sentences to tap |
| **Profile** | A sample profile card (demo data) |
| **Settings** | Manual controls (theme, language, notifications), the assistant model picker, and a link to Developer tools |
| **Developer tools** | Phase 1 tool: paste a JSON prediction and watch validation and execution (the full registry, no AI) |

A navigation bar with real icons switches pages. Dark mode, light mode and "system" are all supported.

## The assistant

The assistant dock sits above the navigation bar on every page.

1. **Off.** A banner says the assistant is off, names the model, and states the one-time download size ("works offline
   afterwards"). **Turn on** downloads (with progress) and loads the model.
2. **Ready.** Sample phrases appear as chips; type a request and send.
3. **Result card.** The user's request, a three-step indicator (**Understood -> Checked -> Done**), and one of:

| Outcome | Looks like | Nothing/something ran |
|---|---|---|
| Done | green check, "Theme set to dark" | the validated action ran |
| Needs your choice | question ("Which theme do you want?") with the options as chips and **None of these** | nothing ran yet |
| Can't do that | info message ("I can't do that. I can change the theme or open a page.") | nothing ran |
| Refused | shield message ("I understood something I can't safely do, so nothing was changed.") | nothing ran |
| Failed | error message | nothing ran |

4. **How this was handled** (collapsible). Request, raw model output, prediction, validation result, execution result, latency, and
   the user's choice if there was a question. This is the technical trace for developers and for trust.

The step indicator makes the architecture visible: the model only produces the first step; the app performs the checks and the
execution.

## The question flow

When a request clearly refers to an action but omits the value ("Change the theme", "Open a page"), the model does not guess. The
app shows the registered options and the **user** decides. "None of these" cancels and changes nothing. The chosen value is
validated like any other before it runs.

## Model picker

Settings lists the catalog models with their size. Choosing one disposes the current model and loads the new one.

## Running it

```bash
flutter run -d <simulator-id> --dart-define=MODEL=gemma4 --dart-define=MODEL_FILE=/absolute/path/model.litertlm
```

`PROMPT=clarify_prompt_v4` (default) offers the question function; other prompt ids run the older behaviour.

## Testing

`test/app/assistant_ui_test.dart` drives the UI with a scripted stand-in model (clear request, vague request and answer,
"None of these", declined request, invalid proposals, language flip, Developer tools).
