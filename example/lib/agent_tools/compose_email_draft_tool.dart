import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:url_launcher/url_launcher.dart';

class ComposeEmailDraftTool {
  Future<ToolResult> execute(ToolCall call) async {
    final toValue = call.arguments['to'];
    if (toValue is! String || toValue.trim().isEmpty) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'to must be a non-empty email address string.',
      );
    }

    final subject = (call.arguments['subject'] as String?)?.trim() ?? '';
    final body = (call.arguments['body'] as String?)?.trim() ?? '';

    final uri = Uri(
      scheme: 'mailto',
      path: toValue.trim(),
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'Unable to open email composer.',
      );
    }

    return ToolResult.ok(
      'Email draft opened.',
      data: {'to': toValue.trim(), if (subject.isNotEmpty) 'subject': subject},
    );
  }
}
