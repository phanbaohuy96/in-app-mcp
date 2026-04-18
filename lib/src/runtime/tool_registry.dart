import '../model/preview.dart';
import '../model/tool_call.dart';
import '../model/tool_definition.dart';
import '../model/tool_error_code.dart';
import '../model/tool_result.dart';

/// Optional side-effect-free previewer attached to a tool via
/// `InAppMcp.registerTool(previewer: ...)`.
///
/// Receives a validated-shape [ToolCall] (arguments have not been type-checked
/// yet, but the tool has been resolved) and returns a [Preview] describing
/// what the handler would do. Callers use this *before* showing a
/// confirmation UI so the user can spot LLM mistakes early.
typedef ToolPreviewer = Future<Preview> Function(ToolCall call);

/// Optional reverse-effect handler attached to a tool via
/// `InAppMcp.registerTool(undoer: ...)`.
///
/// Receives the original [ToolCall] and the [ToolResult] from the successful
/// execution, and performs the inverse side effect. Returning a success
/// [ToolResult] marks the audit entry as undone.
typedef ToolUndoer =
    Future<ToolResult> Function(ToolCall call, ToolResult original);

/// Pairing of a [ToolDefinition] with its [ToolHandler] plus optional
/// [previewer] and [undoer] hooks, as stored in [ToolRegistry].
class RegisteredTool {
  /// Creates a binding between [definition] and its [handler].
  const RegisteredTool({
    required this.definition,
    required this.handler,
    this.previewer,
    this.undoer,
  });

  /// Declarative contract for the tool.
  final ToolDefinition definition;

  /// Handler to invoke once validation + policy have passed.
  final ToolHandler handler;

  /// Optional side-effect-free previewer.
  final ToolPreviewer? previewer;

  /// Optional reverse-effect handler.
  final ToolUndoer? undoer;
}

/// Holds the set of tools the runtime can invoke and validates
/// [ToolCall.arguments] against their [ToolDefinition] before dispatching.
class ToolRegistry {
  /// Creates an empty registry.
  ToolRegistry();

  final Map<String, RegisteredTool> _tools = {};

  /// Registers (or replaces) a tool under [ToolDefinition.name].
  void registerTool({
    required ToolDefinition definition,
    required ToolHandler handler,
    ToolPreviewer? previewer,
    ToolUndoer? undoer,
  }) {
    _tools[definition.name] = RegisteredTool(
      definition: definition,
      handler: handler,
      previewer: previewer,
      undoer: undoer,
    );
  }

  /// Returns an unmodifiable snapshot of all currently-registered tool
  /// definitions.
  List<ToolDefinition> listTools() {
    return _tools.values.map((tool) => tool.definition).toList(growable: false);
  }

  /// Looks up a registered tool by name, or `null` if none is registered.
  RegisteredTool? find(String toolName) => _tools[toolName];

  /// Validates [call] against [tool]'s schema and invokes its handler on
  /// success. Used by [InvocationEngine] after policy gating; callers that
  /// already hold a [RegisteredTool] can skip the [find] lookup.
  Future<ToolResult> invokeRegistered(
    RegisteredTool tool,
    ToolCall call,
  ) async {
    final validationErrors = tool.definition.validateArguments(call.arguments);
    if (validationErrors.isNotEmpty) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        validationErrors.join('; '),
      );
    }

    return tool.handler(call);
  }

  /// Resolves [ToolCall.toolName] to a registered tool, validates, and
  /// invokes. Returns `tool_not_found` if no tool matches.
  Future<ToolResult> invoke(ToolCall call) async {
    final tool = find(call.toolName);
    if (tool == null) {
      return ToolResult.fail(
        ToolErrorCode.toolNotFound,
        'Tool ${call.toolName} is not registered.',
      );
    }

    return invokeRegistered(tool, call);
  }
}
