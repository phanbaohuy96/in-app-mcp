import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenMapDirectionsTool {
  Future<ToolResult> execute(ToolCall call) async {
    final destinationValue = call.arguments['destination'];
    if (destinationValue is! String || destinationValue.trim().isEmpty) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'destination must be a non-empty string.',
      );
    }

    final mode =
        (call.arguments['travelMode'] as String?)?.trim().toLowerCase() ??
        'driving';
    const allowedModes = {'driving', 'walking', 'bicycling', 'transit'};
    if (!allowedModes.contains(mode)) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'travelMode must be one of driving, walking, bicycling, or transit.',
      );
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destinationValue.trim(),
      'travelmode': mode,
    });

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'Unable to open maps application.',
      );
    }

    return ToolResult.ok(
      'Directions opened.',
      data: {
        'destination': destinationValue.trim(),
        'travelMode': mode,
        'url': uri.toString(),
      },
    );
  }
}
