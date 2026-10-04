import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/video_controller.dart';
import '../ui/global_widgets/snackbar.dart';

/// iOS has no FLAG_SECURE. This listens for screen recording and screenshots.
class ScreenGuardService extends GetxService {
  static const MethodChannel _channel = MethodChannel('karam/screen_guard');

  final RxBool isRecording = false.obs;

  Future<ScreenGuardService> init() async {
    if (!Platform.isIOS) return this;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCaptureChanged') {
        final recording = call.arguments == true;
        isRecording.value = recording;
        if (recording) {
          _pauseVideo();
        }
      } else if (call.method == 'onScreenshot') {
        _showScreenshotWarning();
      }
    });

    try {
      final captured = await _channel.invokeMethod<bool>('isCaptured');
      isRecording.value = captured == true;
      if (isRecording.value) {
        _pauseVideo();
      }
    } catch (e) {
      print('Screen guard init failed: $e');
    }

    return this;
  }

  void _pauseVideo() {
    if (Get.isRegistered<VideoController>()) {
      Get.find<VideoController>().pauseForProtection();
    }
  }

  void _showScreenshotWarning() {
    final context = Get.context;
    if (context == null) return;
    ShamraSnackBar.show(
      context: context,
      message: 'تصوير الشاشة غير مسموح لهذا المحتوى',
      type: SnackBarType.warning,
    );
  }
}
