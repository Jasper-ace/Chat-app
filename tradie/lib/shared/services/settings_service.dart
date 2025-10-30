import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyPrefix = 'settings_';

  // Notification Settings Keys
  static const String _newMessages = '${_keyPrefix}new_messages';
  static const String _messagePreview = '${_keyPrefix}message_preview';
  static const String _messageSound = '${_keyPrefix}message_sound';
  static const String _statusChanges = '${_keyPrefix}status_changes';
  static const String _newJobRequests = '${_keyPrefix}new_job_requests';
  static const String _quotesEstimates = '${_keyPrefix}quotes_estimates';
  static const String _pushNotifications = '${_keyPrefix}push_notifications';
  static const String _emailNotifications = '${_keyPrefix}email_notifications';
  static const String _doNotDisturb = '${_keyPrefix}do_not_disturb';

  // Privacy Settings Keys
  static const String _showOnlineStatus = '${_keyPrefix}show_online_status';
  static const String _showLastSeen = '${_keyPrefix}show_last_seen';
  static const String _showProfilePhoto = '${_keyPrefix}show_profile_photo';
  static const String _showPhoneNumber = '${_keyPrefix}show_phone_number';
  static const String _readReceipts = '${_keyPrefix}read_receipts';
  static const String _allowMessageRequests =
      '${_keyPrefix}allow_message_requests';
  static const String _blockUnknownUsers = '${_keyPrefix}block_unknown_users';
  static const String _shareUsageData = '${_keyPrefix}share_usage_data';
  static const String _personalizedAds = '${_keyPrefix}personalized_ads';
  static const String _locationSharing = '${_keyPrefix}location_sharing';

  // Chat Settings Keys
  static const String _autoDownloadImages = '${_keyPrefix}auto_download_images';
  static const String _autoDownloadVideos = '${_keyPrefix}auto_download_videos';
  static const String _chatBackup = '${_keyPrefix}chat_backup';
  static const String _chatTheme = '${_keyPrefix}chat_theme';
  static const String _fontSize = '${_keyPrefix}font_size';

  // Notification Settings
  static Future<bool> getNewMessagesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_newMessages) ?? true;
  }

  static Future<void> setNewMessagesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newMessages, enabled);
  }

  static Future<bool> getMessagePreviewEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_messagePreview) ?? true;
  }

  static Future<void> setMessagePreviewEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messagePreview, enabled);
  }

  static Future<bool> getMessageSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_messageSound) ?? true;
  }

  static Future<void> setMessageSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messageSound, enabled);
  }

  static Future<bool> getStatusChangesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_statusChanges) ?? true;
  }

  static Future<void> setStatusChangesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statusChanges, enabled);
  }

  static Future<bool> getNewJobRequestsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_newJobRequests) ?? true;
  }

  static Future<void> setNewJobRequestsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newJobRequests, enabled);
  }

  static Future<bool> getQuotesEstimatesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_quotesEstimates) ?? true;
  }

  static Future<void> setQuotesEstimatesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quotesEstimates, enabled);
  }

  static Future<bool> getPushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushNotifications) ?? true;
  }

  static Future<void> setPushNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotifications, enabled);
  }

  static Future<bool> getEmailNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_emailNotifications) ?? false;
  }

  static Future<void> setEmailNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotifications, enabled);
  }

  static Future<bool> getDoNotDisturbEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_doNotDisturb) ?? false;
  }

  static Future<void> setDoNotDisturbEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doNotDisturb, enabled);
  }

  // Privacy Settings
  static Future<bool> getShowOnlineStatusEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showOnlineStatus) ?? true;
  }

  static Future<void> setShowOnlineStatusEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showOnlineStatus, enabled);
  }

  static Future<bool> getShowLastSeenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showLastSeen) ?? true;
  }

  static Future<void> setShowLastSeenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showLastSeen, enabled);
  }

  static Future<bool> getShowProfilePhotoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showProfilePhoto) ?? true;
  }

  static Future<void> setShowProfilePhotoEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showProfilePhoto, enabled);
  }

  static Future<bool> getShowPhoneNumberEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showPhoneNumber) ?? false;
  }

  static Future<void> setShowPhoneNumberEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPhoneNumber, enabled);
  }

  static Future<bool> getReadReceiptsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_readReceipts) ?? true;
  }

  static Future<void> setReadReceiptsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_readReceipts, enabled);
  }

  static Future<bool> getAllowMessageRequestsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_allowMessageRequests) ?? true;
  }

  static Future<void> setAllowMessageRequestsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allowMessageRequests, enabled);
  }

  static Future<bool> getBlockUnknownUsersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_blockUnknownUsers) ?? false;
  }

  static Future<void> setBlockUnknownUsersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blockUnknownUsers, enabled);
  }

  static Future<bool> getShareUsageDataEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shareUsageData) ?? false;
  }

  static Future<void> setShareUsageDataEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shareUsageData, enabled);
  }

  static Future<bool> getPersonalizedAdsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_personalizedAds) ?? false;
  }

  static Future<void> setPersonalizedAdsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_personalizedAds, enabled);
  }

  static Future<bool> getLocationSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationSharing) ?? true;
  }

  static Future<void> setLocationSharingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationSharing, enabled);
  }

  // Chat Settings
  static Future<bool> getAutoDownloadImagesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoDownloadImages) ?? true;
  }

  static Future<void> setAutoDownloadImagesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDownloadImages, enabled);
  }

  static Future<bool> getAutoDownloadVideosEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoDownloadVideos) ?? false;
  }

  static Future<void> setAutoDownloadVideosEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDownloadVideos, enabled);
  }

  static Future<bool> getChatBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chatBackup) ?? true;
  }

  static Future<void> setChatBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatBackup, enabled);
  }

  static Future<String> getChatTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chatTheme) ?? 'default';
  }

  static Future<void> setChatTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatTheme, theme);
  }

  static Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSize) ?? 16.0;
  }

  static Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSize, size);
  }

  // Utility Methods
  static Future<Map<String, dynamic>> getAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));

    Map<String, dynamic> settings = {};
    for (final key in keys) {
      final value = prefs.get(key);
      settings[key.replaceFirst(_keyPrefix, '')] = value;
    }

    return settings;
  }

  static Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<void> exportSettings() async {
    final settings = await getAllSettings();
    // TODO: Implement settings export functionality
    print('Settings export: $settings');
  }

  static Future<void> importSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in settings.entries) {
      final key = '$_keyPrefix${entry.key}';
      final value = entry.value;

      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    }
  }
}
