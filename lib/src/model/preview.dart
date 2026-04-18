/// Human-readable + structured description of what a tool would do if
/// invoked, returned by an optional `ToolPreviewer` registered alongside a
/// tool's handler.
///
/// Previews are pure — they must never perform side effects. The runtime
/// calls them *before* showing a confirmation UI so the user can spot LLM
/// mistakes (literal placeholders, out-of-range numbers, unexpected targets)
/// while the tool call is still reversible by declining.
class Preview {
  /// Creates a preview.
  const Preview({
    required this.summary,
    this.data = const {},
    this.warnings = const [],
  });

  /// Short human-readable sentence describing the would-be effect. Rendered
  /// verbatim in the confirmation card.
  final String summary;

  /// Structured payload mirroring the shape of the tool's eventual
  /// [ToolResult.data] — free-form, for app-specific UI.
  final Map<String, dynamic> data;

  /// Zero or more machine-readable warnings the previewer flagged — e.g.
  /// "arguments look templated", "destination unreachable".
  final List<PreviewWarning> warnings;

  /// Serialises the preview for transport / logging.
  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'data': data,
      'warnings': [for (final w in warnings) w.toJson()],
    };
  }
}

/// Severity-free warning produced by a previewer to flag a suspicious
/// argument (templated placeholder, out-of-range value, etc.).
class PreviewWarning {
  /// Creates a preview warning.
  const PreviewWarning({required this.code, required this.message});

  /// Machine-readable code for filtering / styling.
  final String code;

  /// Human-readable message surfaced in the UI.
  final String message;

  /// Serialises the warning for transport / logging.
  Map<String, dynamic> toJson() => {'code': code, 'message': message};
}
