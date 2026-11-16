import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 앱이 뒤에 있거나 꺼져 있을 때 폭발 시각에 알림(폭발음)을 띄웁니다.
class Alarm {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'bomb_explode_v1',
      '폭발 알림',
      channelDescription: '타이머가 끝나면 폭발음과 함께 알려줍니다',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      sound: RawResourceAndroidNotificationSound('boom'),
      playSound: true,
      enableVibration: true,
      icon: 'ic_stat_bomb',
      color: Color(0xFFE8501A),
      visibility: NotificationVisibility.public,
    ),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_bomb')),
      );
    } catch (_) {
      // 알림을 못 쓰는 환경(테스트 등)에서도 타이머는 동작해야 함
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> schedule(DateTime at) async {
    final when = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    for (final mode in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]) {
      try {
        await _plugin.zonedSchedule(
          id: _id,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: mode,
          title: '💥 BOOM!',
          body: '1시간이 지났습니다',
        );
        return;
      } catch (_) {
        // 정확한 알람 권한이 없으면 일반 알람으로 재시도
      }
    }
  }

  static Future<void> cancel() async {
    try {
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}
