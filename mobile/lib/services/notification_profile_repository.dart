import '../models/notification_profile.dart';
import 'backend_api_client.dart';

class NotificationProfileRepository {
  NotificationProfileRepository._();

  static final NotificationProfileRepository instance =
      NotificationProfileRepository._();

  Future<NotificationProfile> fetchProfile() async {
    final body = await BackendApiClient.instance.getJson(
      '/notification-profile/me',
    );
    return _readProfile(body);
  }

  Future<NotificationProfile> updateProfile({
    bool? vocalHygieneEnabled,
    int? maxDailyNotifications,
    List<String>? preferredTimes,
    Map<String, String>? quietHours,
    List<String>? enabledTopics,
  }) async {
    final body = await BackendApiClient.instance.patchJson(
      '/notification-profile/me',
      <String, Object?>{
        if (vocalHygieneEnabled != null)
          'vocal_hygiene_enabled': vocalHygieneEnabled,
        if (maxDailyNotifications != null)
          'max_daily_notifications': maxDailyNotifications,
        if (preferredTimes != null) 'preferred_times': preferredTimes,
        if (quietHours != null) 'quiet_hours': quietHours,
        if (enabledTopics != null) 'enabled_topics': enabledTopics,
      },
    );
    return _readProfile(body);
  }

  NotificationProfile _readProfile(Map<String, dynamic> body) {
    final profileJson = body['notification_profile'];
    if (profileJson is! Map<String, dynamic>) {
      throw const BackendApiException('Bildirim profili okunamadı.');
    }
    return NotificationProfile.fromApi(profileJson);
  }
}
