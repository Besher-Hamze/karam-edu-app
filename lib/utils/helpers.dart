import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../app/ui/global_widgets/snackbar.dart';

class Helpers {
  // تنسيق التاريخ
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // تنسيق الوقت
  static String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  // استخراج اسم الملف من المسار
  static String getFileNameFromPath(String path) {
    return path.split('/').last;
  }

  // حصول على امتداد الملف
  static String getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

  // التحقق من نوع الملف
  static bool isImageFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['jpg', 'jpeg', 'png', 'gif'].contains(ext);
  }

  static bool isPdfFile(String fileName) {
    return getFileExtension(fileName) == 'pdf';
  }

  static bool isDocFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['doc', 'docx'].contains(ext);
  }

  // إظهار رسالة نجاح
  static void showSuccessSnackbar(String title, String message) {
    final context = Get.context;
    if (context != null) {
      ShamraSnackBar.show(
        context: context,
        message: '$title: $message',
        type: SnackBarType.success,
      );
    }
  }

  // إظهار رسالة خطأ
  static void showErrorSnackbar(String title, String message) {
    final context = Get.context;
    if (context != null) {
      ShamraSnackBar.show(
        context: context,
        message: '$title: $message',
        type: SnackBarType.error,
      );
    }
  }
}

