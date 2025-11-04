import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:open_filex/open_filex.dart';
import 'network_service.dart';
import '../data/repositories/file_repository.dart';
import '../ui/global_widgets/snackbar.dart';

class MediaService extends GetxService {
  final NetworkService _networkService = Get.find<NetworkService>();
  late final FileRepository _fileRepository;

  // تهيئة الخدمة
  Future<MediaService> init() async {
    _fileRepository = Get.find<FileRepository>();
    return this;
  }

  // تنزيل وفتح ملف (new - using fileId)
  Future<void> downloadAndOpenFileById(String fileId, String fileName) async {
    try {
      // Get signed URL from backend
      final String? fileUrl = await _fileRepository.getFileUrl(fileId);
      
      if (fileUrl == null) {
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message: 'خطأ: فشل الحصول على رابط الملف',
            type: SnackBarType.error,
          );
        }
        return;
      }

      // التحقق مما إذا كان الملف موجودًا في ذاكرة التخزين المؤقت
      final cachedFile = await DefaultCacheManager().getFileFromCache(fileUrl);

      if (cachedFile != null) {
        // فتح الملف من ذاكرة التخزين المؤقت
        await OpenFilex.open(cachedFile.file.path);
      } else {
        // تنزيل الملف وتخزينه في ذاكرة التخزين المؤقت
        final file = await DefaultCacheManager().getSingleFile(fileUrl);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تنزيل الملف',
          type: SnackBarType.error,
        );
      }
      rethrow;
    }
  }

  // تنزيل وفتح ملف (deprecated - kept for backward compatibility)
  @Deprecated('Use downloadAndOpenFileById instead')
  Future<void> downloadAndOpenFile(String filePath, String fileName) async {
    try {
      // إنشاء الرابط الكامل للملف
      final String fileUrl = '${_networkService.baseUrl}/$filePath';

      // التحقق مما إذا كان الملف موجودًا في ذاكرة التخزين المؤقت
      final cachedFile = await DefaultCacheManager().getFileFromCache(fileUrl);

      if (cachedFile != null) {
        // فتح الملف من ذاكرة التخزين المؤقت
        await OpenFilex.open(cachedFile.file.path);
      } else {
        // تنزيل الملف وتخزينه في ذاكرة التخزين المؤقت
        final file = await DefaultCacheManager().getSingleFile(fileUrl);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تنزيل الملف',
          type: SnackBarType.error,
        );
      }
      rethrow;
    }
  }

  // تنزيل ملف إلى المسار المحدد (new - using fileId)
  Future<String?> downloadFileById(String fileId, String fileName) async {
    try {
      // Get signed URL from backend
      final String? fileUrl = await _fileRepository.getFileUrl(fileId);
      
      if (fileUrl == null) {
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message: 'خطأ: فشل الحصول على رابط الملف',
            type: SnackBarType.error,
          );
        }
        return null;
      }

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
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تنزيل الملف',
          type: SnackBarType.error,
        );
      }
      return null;
    }
  }

  // تنزيل ملف إلى المسار المحدد (deprecated - kept for backward compatibility)
  @Deprecated('Use downloadFileById instead')
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
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تنزيل الملف',
          type: SnackBarType.error,
        );
      }
      return null;
    }
  }
}
