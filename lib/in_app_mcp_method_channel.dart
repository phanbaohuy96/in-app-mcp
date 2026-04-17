import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'in_app_mcp_platform_interface.dart';

/// An implementation of [InAppMcpPlatform] that uses method channels.
class MethodChannelInAppMcp extends InAppMcpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('in_app_mcp');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
