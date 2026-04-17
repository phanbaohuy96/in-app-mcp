import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'in_app_mcp_method_channel.dart';

abstract class InAppMcpPlatform extends PlatformInterface {
  /// Constructs a InAppMcpPlatform.
  InAppMcpPlatform() : super(token: _token);

  static final Object _token = Object();

  static InAppMcpPlatform _instance = MethodChannelInAppMcp();

  /// The default instance of [InAppMcpPlatform] to use.
  ///
  /// Defaults to [MethodChannelInAppMcp].
  static InAppMcpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [InAppMcpPlatform] when
  /// they register themselves.
  static set instance(InAppMcpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
