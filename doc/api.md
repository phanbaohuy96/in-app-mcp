# API Reference

## InAppMcp

Main facade for runtime behavior.

### Constructor

```dart
InAppMcp({
  PolicyStore? policyStore,
  ToolPolicy defaultPolicy = ToolPolicy.confirm,
})
```

### Methods

#### `registerTool`

```dart
void registerTool({
  required ToolDefinition definition,
  required ToolHandler handler,
})
```

Registers one tool in registry.

#### `tools`

```dart
List<ToolDefinition> get tools
```

Returns registered tool definitions.

#### `handleToolCall`

```dart
Future<ToolResult> handleToolCall(
  ToolCall call, {
  bool confirmed = false,
})
```

Evaluates policy and runs tool.

#### `setToolPolicy`

```dart
Future<void> setToolPolicy(String toolName, ToolPolicy policy)
```

Sets policy for one tool.

#### `getToolPolicy`

```dart
Future<ToolPolicy> getToolPolicy(String toolName)
```

Returns current policy, or default if unset.

#### `getPolicyDecision`

```dart
Future<PolicyDecision> getPolicyDecision(String toolName)
```

Returns effective decision (`allow`, `requireConfirmation`, `deny`).

---

## ToolCall

```dart
ToolCall({
  required String id,
  required String toolName,
  required Map<String, dynamic> arguments,
  String? requestId,
})
```

Helpers:
- `ToolCall.fromJson(Map<String, dynamic>)`
- `toJson()`

---

## ToolDefinition

Defines a tool contract.

```dart
ToolDefinition({
  required String name,
  required String description,
  required Map<String, ToolArgType> argumentTypes,
  Set<String> requiredArguments = const {},
  bool allowAdditionalArguments = true,
})
```

### Validator

```dart
List<String> validateArguments(Map<String, dynamic> arguments)
```

Validates required keys and top-level primitive types.

---

## ToolArgType

Enum values:
- `string`
- `integer`
- `number`
- `boolean`
- `array`
- `object`

---

## ToolHandler

```dart
typedef ToolHandler = Future<ToolResult> Function(ToolCall call);
```

---

## ToolResult

```dart
ToolResult({
  required bool success,
  required String message,
  String? code,
  Map<String, dynamic> data = const {},
})
```

Factories:
- `ToolResult.ok(String message, {Map<String, dynamic> data = const {}})`
- `ToolResult.fail(String code, String message, {Map<String, dynamic> data = const {}})`

---

## Error codes

`ToolErrorCode` constants:
- `toolNotFound`
- `invalidArguments`
- `policyDenied`
- `confirmationRequired`

String values are:
- `tool_not_found`
- `invalid_arguments`
- `policy_denied`
- `confirmation_required`

---

## Policy

### ToolPolicy
- `auto`
- `confirm`
- `deny`

### PolicyDecision
- `allow`
- `requireConfirmation`
- `deny`

### PolicyStore

```dart
abstract class PolicyStore {
  Future<void> setToolPolicy(String toolName, ToolPolicy policy);
  Future<ToolPolicy?> getToolPolicy(String toolName);
}
```

### InMemoryPolicyStore

Default in-memory map-based policy store.

---

## ToolRegistry

Methods:
- `registerTool(...)`
- `listTools()`
- `find(toolName)`
- `invoke(call)`
- `invokeRegistered(tool, call)`

---

## InvocationEngine

Method:
- `handle({call, registry, policyEngine, confirmed})`

Use through `InAppMcp` unless you need low-level runtime composition.
