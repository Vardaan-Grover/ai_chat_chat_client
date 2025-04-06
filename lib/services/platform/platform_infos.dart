import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logging/logging.dart';

/// Contains platform-specific information and utilities for determining
/// device capabilities, OS versions, and application metadata.
class PlatformInfos {
  // Private constructor to prevent instantiation
  PlatformInfos._();

  static final Logger _logger = Logger('PlatformInfos');

  // Cached values
  static PackageInfo? _packageInfo;
  static Map<String, dynamic>? _deviceInfo;
  static String? _deviceId;

  /// Whether the app is running on web
  static bool get isWeb => kIsWeb;

  /// Whether the app is running on Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Whether the app is running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Whether the app is running on macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Whether the app is running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Whether the app is running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Whether the app is running on Fuchsia
  static bool get isFuchsia => !kIsWeb && Platform.isFuchsia;

  /// Whether the app is running on any desktop platform (Linux, Windows, macOS)
  static bool get isDesktop => isLinux || isWindows || isMacOS;

  /// Whether the app is running on any mobile platform (iOS, Android)
  static bool get isMobile => isIOS || isAndroid;

  /// Whether the app is running on any Apple platform (iOS, macOS)
  static bool get isApple => isIOS || isMacOS;

  /// The operating system name (e.g., "android", "ios")
  static String get operatingSystem =>
      kIsWeb ? 'Web' : Platform.operatingSystem;

  /// The operating system version
  static String get operatingSystemVersion =>
      kIsWeb ? 'Unknown' : Platform.operatingSystemVersion;

  /// Gets package information
  static Future<PackageInfo> get packageInfo async {
    if (_packageInfo != null) return _packageInfo!;

    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      _logger.warning('Failed to get package info', e);
      // Fallback with minimal info
      _packageInfo = PackageInfo(
        appName: 'Unknown',
        packageName: 'unknown',
        version: '0.0.0',
        buildNumber: '0',
      );
    }

    return _packageInfo!;
  }

  /// The package name (e.g., com.example.app)
  static Future<String> get packageName async =>
      (await packageInfo).packageName;

  /// The app name as displayed to users
  static Future<String> get appName async => (await packageInfo).appName;

  /// The app version (e.g., 1.0.0)
  static Future<String> get appVersion async => (await packageInfo).version;

  /// The app build number (e.g., 42)
  static Future<String> get buildNumber async =>
      (await packageInfo).buildNumber;

  /// Information about the current device
  static Future<Map<String, dynamic>> get deviceInfoMap async {
    if (_deviceInfo != null) return _deviceInfo!;

    final deviceInfoPlugin = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        _deviceInfo = {
          'browser': webInfo.browserName.toString(),
          'platform': webInfo.platform ?? 'unknown',
          'userAgent': webInfo.userAgent ?? 'unknown',
          'deviceMemory': webInfo.deviceMemory ?? 0,
        };
      } else if (isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        _deviceInfo = {
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'sdkInt': androidInfo.version.sdkInt,
          'release': androidInfo.version.release,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'hardware': androidInfo.hardware,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        _deviceInfo = {
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
          'name': iosInfo.name,
          'identifierForVendor': iosInfo.identifierForVendor,
        };
      } else if (isMacOS) {
        final macOsInfo = await deviceInfoPlugin.macOsInfo;
        _deviceInfo = {
          'model': macOsInfo.model,
          'kernelVersion': macOsInfo.kernelVersion,
          'osRelease': macOsInfo.osRelease,
          'hostName': macOsInfo.hostName,
          'arch': macOsInfo.arch,
          'activeCPUs': macOsInfo.activeCPUs,
          'memorySize': macOsInfo.memorySize,
        };
      } else if (isWindows) {
        final windowsInfo = await deviceInfoPlugin.windowsInfo;
        _deviceInfo = {
          'computerName': windowsInfo.computerName,
          'numberOfCores': windowsInfo.numberOfCores,
          'systemMemoryInMegabytes': windowsInfo.systemMemoryInMegabytes,
          'buildNumber': windowsInfo.buildNumber,
          'productName': windowsInfo.productName,
          'editionId': windowsInfo.editionId,
          'userName': windowsInfo.userName,
        };
      } else if (isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        _deviceInfo = {
          'name': linuxInfo.name,
          'version': linuxInfo.version,
          'id': linuxInfo.id,
          'prettyName': linuxInfo.prettyName,
          'versionCodename': linuxInfo.versionCodename,
          'versionId': linuxInfo.versionId,
          'machineId': linuxInfo.machineId,
        };
      } else {
        _deviceInfo = {'unknown': true, 'platform': operatingSystem};
      }
    } catch (e) {
      _logger.warning('Failed to get device info', e);
      _deviceInfo = {'error': e.toString(), 'platform': operatingSystem};
    }

    return _deviceInfo!;
  }

  /// Get a unique device identifier (with appropriate privacy considerations)
  static Future<String> get deviceId async {
    if (_deviceId != null) return _deviceId!;

    try {
      final info = await deviceInfoMap;

      // Create a device ID based on available information
      // This approach maintains privacy while providing reasonable uniqueness
      if (kIsWeb) {
        _deviceId = 'web-${info['browser']}-${info['platform']}';
      } else if (isAndroid) {
        _deviceId = 'android-${info['manufacturer']}-${info['model']}';
      } else if (isIOS) {
        _deviceId = 'ios-${info['model']}';
      } else if (isMacOS) {
        _deviceId = 'macos-${info['model']}';
      } else if (isWindows) {
        _deviceId = 'windows-${info['computerName']}';
      } else if (isLinux) {
        _deviceId = 'linux-${info['prettyName']}';
      } else {
        _deviceId = 'unknown-device';
      }

      // Add a suffix based on app package to avoid collisions across apps
      final pkg = await packageName;
      _deviceId = '$_deviceId-${pkg.split('.').last}';
    } catch (e) {
      _logger.warning('Failed to create device ID', e);
      _deviceId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
    }

    return _deviceId!;
  }

  /// Whether the app is running in debug mode
  static bool get isDebugMode => kDebugMode;

  /// Whether the app is running in release mode
  static bool get isReleaseMode => kReleaseMode;

  /// Whether the app is running in profile mode
  static bool get isProfileMode => kProfileMode;

  /// Whether the device is a tablet (basic detection)
  static Future<bool> get isTablet async {
    if (isAndroid || isIOS) {
      final info = await deviceInfoMap;
      if (isAndroid) {
        // A basic heuristic for Android tablets
        final String model = (info['model'] ?? '').toLowerCase();
        final bool hasTabletKeyword =
            model.contains('tablet') ||
            model.contains('tab') ||
            model.contains('pad');

        // Check screen size if available
        // This requires a context, which we don't have here
        // You might want to add a method that takes screen dimensions as parameters
        return hasTabletKeyword;
      } else if (isIOS) {
        // iPad detection
        final String model = (info['model'] ?? '').toLowerCase();
        return model.contains('ipad');
      }
    }
    return false;
  }

  /// Reset cached values (useful for testing)
  static void resetCache() {
    _packageInfo = null;
    _deviceInfo = null;
    _deviceId = null;
  }

  /// String representation of platform and device information
  static Future<String> get platformSummary async {
    final info = await deviceInfoMap;
    final pkg = await packageInfo;

    return '''
    App: ${pkg.appName} (${pkg.version}+${pkg.buildNumber})
    Platform: $operatingSystem $operatingSystemVersion
    Device: ${info.containsKey('model') ? info['model'] : ''}
    Mode: ${isDebugMode
        ? 'Debug'
        : isReleaseMode
        ? 'Release'
        : 'Profile'}
    ''';
  }
}
