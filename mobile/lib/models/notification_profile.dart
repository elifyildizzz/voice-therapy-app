class NotificationProfile {
  const NotificationProfile({
    required this.id,
    required this.userId,
    required this.vocalHygieneEnabled,
    required this.maxDailyNotifications,
    required this.preferredTimes,
    required this.quietHours,
    required this.enabledTopics,
    required this.activePlan,
  });

  factory NotificationProfile.fromApi(Map<String, dynamic> map) {
    final rawQuietHours = map['quiet_hours'];
    final rawEnabledTopics = map['enabled_topics'];
    final rawPreferredTimes = map['preferred_times'];
    final rawActivePlan = map['active_plan'];

    return NotificationProfile(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      vocalHygieneEnabled: map['vocal_hygiene_enabled'] as bool? ?? true,
      maxDailyNotifications: map['max_daily_notifications'] as int? ?? 2,
      preferredTimes: rawPreferredTimes is List
          ? rawPreferredTimes.map((item) => item.toString()).toList()
          : const <String>['10:30', '15:30'],
      quietHours: rawQuietHours is Map<String, dynamic>
          ? rawQuietHours.map(
              (key, value) => MapEntry(key, value.toString()),
            )
          : const <String, String>{'start': '22:00', 'end': '09:00'},
      enabledTopics: rawEnabledTopics is List
          ? rawEnabledTopics.map((item) => item.toString()).toList()
          : defaultTopics,
      activePlan: rawActivePlan is Map<String, dynamic>
          ? NotificationPlan.fromApi(rawActivePlan)
          : null,
    );
  }

  static const List<String> defaultTopics = <String>[
    'hydration',
    'nutrition',
    'voice_usage',
    'environmental_factors',
    'irritants',
    'voice_rest',
    'throat_clearing',
    'reflux_control',
  ];

  final String id;
  final String userId;
  final bool vocalHygieneEnabled;
  final int maxDailyNotifications;
  final List<String> preferredTimes;
  final Map<String, String> quietHours;
  final List<String> enabledTopics;
  final NotificationPlan? activePlan;
}

class NotificationPlan {
  const NotificationPlan({
    required this.planId,
    required this.topics,
    required this.items,
  });

  factory NotificationPlan.fromApi(Map<String, dynamic> map) {
    final rawTopics = map['topics'];
    final rawItems = map['items'];

    return NotificationPlan(
      planId: map['plan_id']?.toString() ?? '',
      topics: rawTopics is List
          ? rawTopics.map((item) => item.toString()).toList()
          : const <String>[],
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(NotificationPlanItem.fromApi)
              .toList()
          : const <NotificationPlanItem>[],
    );
  }

  final String planId;
  final List<String> topics;
  final List<NotificationPlanItem> items;
}

class NotificationPlanItem {
  const NotificationPlanItem({
    required this.notificationId,
    required this.topic,
    required this.title,
    required this.body,
    required this.time,
    required this.repeat,
  });

  factory NotificationPlanItem.fromApi(Map<String, dynamic> map) {
    return NotificationPlanItem(
      notificationId: map['notification_id']?.toString() ?? '',
      topic: map['topic']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      repeat: map['repeat']?.toString() ?? '',
    );
  }

  final String notificationId;
  final String topic;
  final String title;
  final String body;
  final String time;
  final String repeat;
}
