import 'package:shared_preferences/shared_preferences.dart';

/// Configuration keys for application settings
/// 
/// This class contains constants for all settings keys used throughout the app,
/// ensuring consistency and preventing typos when accessing shared preferences.
abstract class SettingKeys {
  // Chat rendering preferences
  static const String renderHtml = 'ai_chat_chat.renderHtml';
  static const String hideRedactedEvents = 'ai_chat_chat.hideRedactedEvents';
  static const String hideUnknownEvents = 'ai_chat_chat.hideUnknownEvents';
  static const String hideUnimportantStateEvents = 'ai_chat_chat.hideUnimportantStateEvents';
  static const String separateChatTypes = 'ai_chat_chat.separateChatTypes';
  
  // App appearance settings
  static const String theme = 'theme';
  static const String amoledEnabled = 'amoled_enabled';
  static const String fontSizeFactor = 'ai_chat_chat.font_size_factor';
  
  // Feature toggles
  static const String sentry = 'sentry';
  static const String showNoGoogle = 'ai_chat_chat.show_no_google';
  static const String showNoPid = 'ai_chat_chat.show_no_pid';
  static const String experimentalVoip = 'ai_chat_chat.experimental_voip';
  static const String showPresences = 'ai_chat_chat.show_presences';
  
  // Security settings
  static const String databasePassword = 'database-password';
  static const String appLockKey = 'ai_chat_chat.app_lock';
  
  // Push notification settings
  static const String unifiedPushRegistered = 'ai_chat_chat.unifiedpush.registered';
  static const String unifiedPushEndpoint = 'ai_chat_chat.unifiedpush.endpoint';
  
  // User preferences
  static const String ownStatusMessage = 'ai_chat_chat.status_msg';
  static const String codeLanguage = 'code_language';
  static const String dontAskForBootstrapKey = 'ai_chat_chat.dont_ask_bootstrap';
  static const String autoplayImages = 'ai_chat_chat.autoplay_images';
  static const String sendTypingNotifications = 'ai_chat_chat.send_typing_notifications';
  static const String sendPublicReadReceipts = 'ai_chat_chat.send_public_read_receipts';
  static const String sendOnEnter = 'ai_chat_chat.send_on_enter';
  static const String swipeRightToLeftToReply = 'ai_chat_chat.swipeRightToLeftToReply';
}

/// Typed application settings with default values
///
/// Represents settings with their appropriate types, default values, and storage keys.
/// This enum allows for type-safe access to application settings.
enum AppSettings<T> {
  // Audio recording settings
  audioRecordingNumChannels<int>('audioRecordingNumChannels', 1),
  audioRecordingAutoGain<bool>('audioRecordingAutoGain', true),
  audioRecordingEchoCancel<bool>('audioRecordingEchoCancel', false),
  audioRecordingNoiseSuppress<bool>('audioRecordingNoiseSuppress', true),
  audioRecordingBitRate<int>('audioRecordingBitRate', 64000),
  audioRecordingSamplingRate<int>('audioRecordingSamplingRate', 44100),
  
  // Push notification configuration
  pushNotificationsGatewayUrl<String>(
    'pushNotificationsGatewayUrl',
    'https://your-push-gateway.com/_matrix/push/v1/notify', // Replace with actual gateway URL
  ),
  pushNotificationsPusherFormat<String>(
    'pushNotificationsPusherFormat',
    'event_id_only',
  ),
  
  // E2E encryption settings
  shareKeysWith<String>('ai_chat_chat.share_keys_with', 'all'),
  noEncryptionWarningShown<bool>(
    'ai_chat_chat.no_encryption_warning_shown',
    false,
  ),
  
  // UI layout preferences
  displayChatDetailsColumn<bool>('ai_chat_chat.display_chat_details_column', false);

  final String key;
  final T defaultValue;

  const AppSettings(this.key, this.defaultValue);
}

/// Extension methods for boolean settings
extension AppSettingsBoolExtension on AppSettings<bool> {
  /// Retrieves a boolean setting from SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @return The stored value or default if not found
  bool getItem(SharedPreferences store) => store.getBool(key) ?? defaultValue;

  /// Stores a boolean setting in SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @param value The value to store
  /// @return Future that completes once the value is saved
  Future<void> setItem(SharedPreferences store, bool value) =>
      store.setBool(key, value);
}

/// Extension methods for string settings
extension AppSettingsStringExtension on AppSettings<String> {
  /// Retrieves a string setting from SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @return The stored value or default if not found
  String getItem(SharedPreferences store) =>
      store.getString(key) ?? defaultValue;

  /// Stores a string setting in SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @param value The value to store
  /// @return Future that completes once the value is saved
  Future<void> setItem(SharedPreferences store, String value) =>
      store.setString(key, value);
}

/// Extension methods for integer settings
extension AppSettingsIntExtension on AppSettings<int> {
  /// Retrieves an integer setting from SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @return The stored value or default if not found
  int getItem(SharedPreferences store) => store.getInt(key) ?? defaultValue;

  /// Stores an integer setting in SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @param value The value to store
  /// @return Future that completes once the value is saved
  Future<void> setItem(SharedPreferences store, int value) =>
      store.setInt(key, value);
}

/// Extension methods for double settings
extension AppSettingsDoubleExtension on AppSettings<double> {
  /// Retrieves a double setting from SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @return The stored value or default if not found
  double getItem(SharedPreferences store) =>
      store.getDouble(key) ?? defaultValue;

  /// Stores a double setting in SharedPreferences
  /// 
  /// @param store The SharedPreferences instance
  /// @param value The value to store
  /// @return Future that completes once the value is saved
  Future<void> setItem(SharedPreferences store, double value) =>
      store.setDouble(key, value);
}