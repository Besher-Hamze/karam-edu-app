// lib/app/ui/screens/splash/splash_controller.dart
import 'package:get/get.dart';
import '../../../services/storage_service.dart';
import '../../../services/notification_service.dart';

class SplashController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  @override
  void onInit() {
    super.onInit();
    _checkLoggedInStatus();
  }

  Future<void> _checkLoggedInStatus() async {
    await Future.delayed(Duration(seconds: 2)); // إنتظار 2 ثانية لعرض شاشة البداية

    final token = _storageService.getToken();

    if (token != null) {
      if (Get.isRegistered<NotificationService>()) {
        final notifications = Get.find<NotificationService>();
        await notifications.syncAfterLoginOrOpen();
        await notifications.refreshAppSettings();
      }
      Get.offAllNamed('/home');
    } else {
      Get.offAllNamed('/login');
    }
  }
}
