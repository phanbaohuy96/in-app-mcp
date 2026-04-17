# Example Workflow

This document explains the `example/` app flow end-to-end.

## Goal

Demonstrate how a user prompt can become a safe in-app side effect:

1. user enters prompt
2. adapter builds tool call
3. runtime checks policy
4. optional confirmation
5. tool executes
6. result shown as JSON

## Key files

- `example/lib/main.dart`
- `example/lib/llm/llm_adapter.dart`
- `example/lib/llm/mock_llm_adapter.dart`
- `example/lib/agent_tools/tool_catalog.dart`
- `example/lib/agent_tools/schedule_weekday_alarm_tool.dart`
- `example/lib/screens/settings_policy_screen.dart`
- `example/lib/screens/chat_demo_screen.dart`

## Step-by-step

### 1) App startup

`main.dart` creates `InAppMcp(defaultPolicy: ToolPolicy.confirm)` and registers tools via `ToolCatalog`.

### 2) User chooses policy

`SettingsPolicyScreen` lets user set tool policy for `schedule_weekday_alarm`:
- Auto
- Confirm
- Deny

### 3) Prompt to tool call

`MockLlmAdapter` returns a `ToolCall` with:
- `toolName: schedule_weekday_alarm`
- args (`hour`, `minute`, `weekdays`, `label`)

### 4) Confirmation gate

`ChatDemoScreen` requests `getPolicyDecision`.
- if `requireConfirmation`: shows dialog before execution
- otherwise proceeds immediately

### 5) Tool execution

`ScheduleWeekdayAlarmTool.execute`:
- initializes notifications and timezone data
- validates weekday element range (1..7)
- requests permissions once per session
- schedules repeating weekday notifications
- returns `ToolResult.ok` with `alarmId`, `nextTriggerAt`, `weekdays`

### 6) Result display

`ChatDemoScreen` renders `ToolResult.toJson()` for transparent debugging.

## Run locally

```bash
cd example
flutter pub get
flutter run
```

## Validation commands

```bash
flutter analyze
flutter test
```

Run from `example/` directory.

## Notes

- Web runs can validate UI/policy flow, but alarm scheduling behavior is platform-specific.
- On iOS/Android, first-run permission prompts are expected.
- Timing and exact behavior may vary by OS policy and power optimizations.
