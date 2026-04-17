class ToolResult {
  const ToolResult({
    required this.success,
    required this.message,
    this.code,
    this.data = const {},
  });

  final bool success;
  final String message;
  final String? code;
  final Map<String, dynamic> data;

  factory ToolResult.ok(
    String message, {
    Map<String, dynamic> data = const {},
  }) {
    return ToolResult(success: true, message: message, data: data);
  }

  factory ToolResult.fail(
    String code,
    String message, {
    Map<String, dynamic> data = const {},
  }) {
    return ToolResult(success: false, code: code, message: message, data: data);
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (code != null) 'code': code,
      'data': data,
    };
  }
}
