import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfoHelper {
  static Future<Map<String, String>> getDeviceInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    String osVersion = '';
    String platform = '';

    try {
      if (Platform.isAndroid) {
        osVersion = 'Android ${Platform.operatingSystemVersion}';
        platform = 'Android';
      } else if (Platform.isIOS) {
        osVersion = 'iOS ${Platform.operatingSystemVersion}';
        platform = 'iOS';
      } else {
        osVersion = Platform.operatingSystemVersion;
        platform = Platform.operatingSystem;
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      osVersion = 'Unknown';
      platform = 'Unknown';
    }

    return {
      'App Version': '${packageInfo.version} (${packageInfo.buildNumber})',
      'OS Version': osVersion,
      'Platform': platform,
      'Package Name': packageInfo.packageName,
    };
  }

  static Future<String> getFormattedDeviceInfo() async {
    final info = await getDeviceInfo();
    final buffer = StringBuffer();

    buffer.writeln('--- Device Information ---');
    info.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln('--- End Device Info ---');

    return buffer.toString();
  }
}
