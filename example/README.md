# in_app_mcp_example

Reference integration of [`in_app_mcp`](../README.md) showing the full
**Consent Lifecycle** in a Flutter UI:

- inline tool-call card with a **Preview** row (catches LLM mistakes before any
  side effect runs)
- **grant submenu** next to Run — *Run once* / *Run + allow 5 min* /
  *Run + allow for session* (`mcp.grantFor` / `mcp.grantUntilCleared`)
- inline **Undo** on successful calls, driven by the tool's `@McpToolUndo`
- **Audit timeline** screen (history icon in the app bar) subscribing to
  `mcp.auditLedger.changes`
- **Active grants** card in Settings with per-grant + revoke-all controls

The five demo tools (`schedule_weekday_alarm`, `create_calendar_event`,
`open_map_directions`, `compose_email_draft`, codegen-backed `echo`) live
under `lib/agent_tools/`. `schedule_weekday_alarm` and `echo` ship both a
previewer and an undoer as full-lifecycle examples.

## Run the app

```bash
flutter pub get
flutter run
```

Use `--dart-define=LLM_ADAPTER=gemma` to enable Gemma adapter mode.

## VS Code launch + .env

This repository includes `./.vscode/launch.json` with:
- `Example (Gemma from .env)` using `--dart-define-from-file=.env`
- `Example (Mock)` default run

Default `.env` keys:
- `LLM_ADAPTER`
- `E2E_MODE`
- `MODEL_CACHE_DIR`
- `GEMMA_MODEL_PATH`

## Model download flow

The example app includes a `Models` section where you can:
- download a model file,
- select an active downloaded model,
- delete a downloaded model.

In Gemma mode, selected downloaded model path is preferred over `GEMMA_MODEL_PATH`.
If neither is available, the app falls back to mock adapter.

## Reuse a pre-downloaded local model (recommended for repeated tests)

For Gemma 4 E2B, run the precache script once:

```bash
./scripts/precache_gemma_e2b.sh
```

The script will:
- download `gemma-4-E2B-it.litertlm` into `model_cache/` if missing,
- update `.env` with `LLM_ADAPTER=gemma`, `MODEL_CACHE_DIR`, and `GEMMA_MODEL_PATH`.

Then launch from VS Code with `Example (Gemma from .env)` or run:

```bash
flutter run --dart-define-from-file=.env
```

The app treats that local file as already downloaded and skips re-download.

## Deterministic E2E mode

For automation, run with:

```bash
flutter run --dart-define=LLM_ADAPTER=gemma --dart-define=E2E_MODE=true
```

When `E2E_MODE=true`, the Gemma adapter returns a deterministic tool call payload to keep E2E stable.

## iOS simulator (Gemma) walkthroughs

Screenshots of each Gemma-driven flow on a booted iPhone simulator live
in [`../doc/screenshots/`](../doc/screenshots/) and are embedded in the
root [README.md](../README.md).

Three integration tests regenerate them:

```bash
# Smoke test: single prompt → tool call → run → Succeeded (~60 s).
flutter test -d <booted-simulator-id> \
  integration_test/gemma_echo_flow_test.dart \
  --dart-define=LLM_ADAPTER=gemma \
  --dart-define=GEMMA_MODEL_PATH=$PWD/model_cache/gemma-4-E2B-it.litertlm

# Per-tool showcase (~5–8 min) — regenerates the five tool_*.png screenshots.
flutter test -d <booted-simulator-id> \
  integration_test/tool_showcase_test.dart \
  --dart-define=LLM_ADAPTER=gemma \
  --dart-define=GEMMA_MODEL_PATH=$PWD/model_cache/gemma-4-E2B-it.litertlm

# Consent Lifecycle showcase (~1 min) — preview → grant menu → execute →
# undo → audit timeline. Writes consent_*.png via an embedded screenshot
# watcher that drives xcrun simctl io booted screenshot off the test's
# [SCREENSHOT:<name>] markers.
./scripts/capture_consent_showcase.sh
```

For the first two tests you need to run a parallel shell watcher on the
test's `[SCREENSHOT:<name>]` markers yourself (the consent-lifecycle
script bundles the watcher for convenience).

## Appium (Android)

Appium files are under `e2e/appium`.

```bash
cd e2e/appium
npm ci
```

Start Appium server (example):

```bash
appium --base-path /wd/hub --port 4723
```

Build debug APK from `example/`:

```bash
flutter build apk --debug --dart-define=LLM_ADAPTER=gemma --dart-define=E2E_MODE=true
```

Run E2E spec:

```bash
cd e2e/appium
npm run test:android
```
