import 'package:get/get.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:open_file/open_file.dart';
import 'network_service.dart';

class MediaService extends GetxService {
  final NetworkService _networkService = Get.find<NetworkService>();

  // تهيئة الخدمة
  Future<MediaService> init() async {
    return this;
  }

  // تنزيل وفتح ملف
  Future<void> downloadAndOpenFile(String filePath, String fileName) async {
    try {
      // إنشاء الرابط الكامل للملف
      final String fileUrl = '${_networkService.baseUrl}/$filePath';

      // التحقق مما إذا كان الملف موجودًا في ذاكرة التخزين المؤقت
      final cachedFile = await DefaultCacheManager().getFileFromCache(fileUrl);

      if (cachedFile != null) {
        // فتح الملف من ذاكرة التخزين المؤقت
        await OpenFile.open(cachedFile.file.path);
      } else {
        // تنزيل الملف وتخزينه في ذاكرة التخزين المؤقت
        final file = await DefaultCacheManager().getSingleFile(fileUrl);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تنزيل الملف',
        snackPosition: SnackPosition.BOTTOM,
      );
      rethrow;
    }
  }

  // تنزيل ملف إلى المسار المحدد
  Future<String?> downloadFile(String filePath, String fileName) async {
    try {
      // إنشاء الرابط الكامل للملف
      final String fileUrl = '${_networkService.baseUrl}/$filePath';

      // الحصول على دليل التنزيلات
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/$fileName';

      // تنزيل الملف
      await Dio().download(
        fileUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('تم التنزيل: $progress%');
          }
        },
      );

      return savePath;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تنزيل الملف',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }
}
