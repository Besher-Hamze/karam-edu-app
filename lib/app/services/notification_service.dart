import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../services/network_service.dart';
import '../services/storage_service.dart';

const String kAllStudentsTopic = 'all_students';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();
  FirebaseMessaging? _messaging;
  bool _initialized = false;

  Future<NotificationService> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _messaging = FirebaseMessaging.instance;

      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');

      if (Platform.isAndroid) {
        await _messaging!.setAutoInitEnabled(true);
      }

      _messaging!.onTokenRefresh.listen((token) {
        _registerIfNeeded(force: true, tokenOverride: token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? message.data['title'];
        final body = message.notification?.body ?? message.data['body'];
        if (title != null || body != null) {
          Get.snackbar(
            title?.toString() ?? 'إشعار',
            body?.toString() ?? '',
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 4),
          );
        }
      });

      _initialized = true;
      await syncAfterLoginOrOpen();
      await refreshAppSettings();
    } catch (e, st) {
      debugPrint('NotificationService init failed: $e\n$st');
    }
    return this;
  }

  /// Call on app open (if already logged in) and after login — no need to re-login.
  Future<void> syncAfterLoginOrOpen() async {
    if (!_initialized) return;
    final authToken = _storage.getToken();
    if (authToken == null || authToken.isEmpty) return;
    await _registerIfNeeded();
  }

  Future<void> _registerIfNeeded({
    bool force = false,
    String? tokenOverride,
  }) async {
    try {
      if (_messaging == null) return;
      final authToken = _storage.getToken();
      if (authToken == null || authToken.isEmpty) return;

      final fcmToken = tokenOverride ?? await _messaging!.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('FCM token is null');
        return;
      }

      final cachedToken = _storage.getFcmRegisteredToken();
      final topicOk = _storage.isFcmTopicSubscribed(kAllStudentsTopic);

      if (!force && cachedToken == fcmToken && topicOk) {
        debugPrint('FCM already registered & subscribed (cached)');
        return;
      }

      await _messaging!.subscribeToTopic(kAllStudentsTopic);

      if (!Get.isRegistered<NetworkService>()) return;
      final network = Get.find<NetworkService>();
      await network.post('/notifications/register-token', data: {
        'token': fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });

      await _storage.setFcmRegisteredToken(fcmToken);
      await _storage.setFcmTopicSubscribed(kAllStudentsTopic, true);
      debugPrint('FCM registered and subscribed to $kAllStudentsTopic');
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }

  Future<void> refreshAppSettings() async {
    try {
      final authToken = _storage.getToken();
      if (authToken == null || authToken.isEmpty) return;
      if (!Get.isRegistered<NetworkService>()) return;

      final network = Get.find<NetworkService>();
      final response = await network.get('/app-settings');
      final data = response.data;
      if (data is Map && data['videoOverlayOpacity'] != null) {
        final opacity = (data['videoOverlayOpacity'] as num).toDouble();
        await _storage.setVideoOverlayOpacity(opacity.clamp(0.0, 1.0));
      }
    } catch (e) {
      debugPrint('App settings fetch failed: $e');
    }
  }
}
