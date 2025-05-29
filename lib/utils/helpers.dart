import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

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
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green[100],
      colorText: Colors.green[800],
      margin: EdgeInsets.all(8),
      borderRadius: 10,
      icon: Icon(
        Icons.check_circle,
        color: Colors.green[800],
      ),
    );
  }

  // إظهار رسالة خطأ
  static void showErrorSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red[100],
      colorText: Colors.red[800],
      margin: EdgeInsets.all(8),
      borderRadius: 10,
      icon: Icon(
        Icons.error,
        color: Colors.red[800],
      ),
    );
  }
}

