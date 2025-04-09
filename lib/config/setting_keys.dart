import 'package:shared_preferences/shared_preferences.dart';

// TODO: Change this config on the basis of the new app name

abstract class SettingKeys {
  static const String renderHtml = 'ai_chat_chat.renderHtml';
  static const String hideRedactedEvents = 'ai_chat_chat.hideRedactedEvents';
  static const String hideUnknownEvents = 'ai_chat_chat.hideUnknownEvents';
  static const String hideUnimportantStateEvents =
      'ai_chat_chat.hideUnimportantStateEvents';
  static const String separateChatTypes = 'ai_chat_chat.separateChatTypes';
  static const String sentry = 'sentry';
  static const String theme = 'theme';
  static const String amoledEnabled = 'amoled_enabled';
  static const String codeLanguage = 'code_language';
  static const String showNoGoogle = 'ai_chat_chat.show_no_google';
  static const String fontSizeFactor = 'ai_chat_chat.font_size_factor';
  static const String showNoPid = 'ai_chat_chat.show_no_pid';
  static const String databasePassword = 'database-password';
  static const String appLockKey = 'ai_chat_chat.app_lock';
  static const String unifiedPushRegistered =
      'ai_chat_chat.unifiedpush.registered';
  static const String unifiedPushEndpoint = 'ai_chat_chat.unifiedpush.endpoint';
  static const String ownStatusMessage = 'ai_chat_chat.status_msg';
  static const String dontAskForBootstrapKey =
      'ai_chat_chat.dont_ask_bootstrap';
  static const String autoplayImages = 'ai_chat_chat.autoplay_images';
  static const String sendTypingNotifications =
      'ai_chat_chat.send_typing_notifications';
  static const String sendPublicReadReceipts =
      'ai_chat_chat.send_public_read_receipts';
  static const String sendOnEnter = 'ai_chat_chat.send_on_enter';
  static const String swipeRightToLeftToReply =
      'ai_chat_chat.swipeRightToLeftToReply';
  static const String experimentalVoip = 'ai_chat_chat.experimental_voip';
  static const String showPresences = 'ai_chat_chat.show_presences';
}

enum AppSettings<T> {
  audioRecordingNumChannels<int>('audioRecordingNumChannels', 1),
  audioRecordingAutoGain<bool>('audioRecordingAutoGain', true),
  audioRecordingEchoCancel<bool>('audioRecordingEchoCancel', false),
  audioRecordingNoiseSuppress<bool>('audioRecordingNoiseSuppress', true),
  audioRecordingBitRate<int>('audioRecordingBitRate', 64000),
  audioRecordingSamplingRate<int>('audioRecordingSamplingRate', 44100),
  pushNotificationsGatewayUrl<String>(
    'pushNotificationsGatewayUrl',
    'https://your-push-gateway.com/_matrix/push/v1/notify', // Change this URL to yours
  ),
  pushNotificationsPusherFormat<String>(
    'pushNotificationsPusherFormat',
    'event_id_only',
  ),
  shareKeysWith<String>('ai_chat_chat.share_keys_with', 'all'),
  noEncryptionWarningShown<bool>(
    'ai_chat_chat.no_encryption_warning_shown',
    false,
  ),
  displayChatDetailsColumn('ai_chat_chat.display_chat_details_column', false);

  final String key;
  final T defaultValue;

  const AppSettings(this.key, this.defaultValue);
}

extension AppSettingsBoolExtension on AppSettings<bool> {
  bool getItem(SharedPreferences store) => store.getBool(key) ?? defaultValue;

  Future<void> setItem(SharedPreferences store, bool value) =>
      store.setBool(key, value);
}

extension AppSettingsStringExtension on AppSettings<String> {
  String getItem(SharedPreferences store) =>
      store.getString(key) ?? defaultValue;

  Future<void> setItem(SharedPreferences store, String value) =>
      store.setString(key, value);
}

extension AppSettingsIntExtension on AppSettings<int> {
  int getItem(SharedPreferences store) => store.getInt(key) ?? defaultValue;

  Future<void> setItem(SharedPreferences store, int value) =>
      store.setInt(key, value);
}

extension AppSettingsDoubleExtension on AppSettings<double> {
  double getItem(SharedPreferences store) =>
      store.getDouble(key) ?? defaultValue;

  Future<void> setItem(SharedPreferences store, double value) =>
      store.setDouble(key, value);
}