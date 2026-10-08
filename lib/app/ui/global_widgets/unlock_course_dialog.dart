import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../theme/color_theme.dart';
import 'snackbar.dart';

/// Code / QR dialog for unlocking a course. [onUnlocked] runs after a successful
/// code redeem and after returning from the QR scanner.
void showUnlockCourseDialog(
  BuildContext context, {
  required String courseId,
  Future<void> Function()? onUnlocked,
}) {
  final homeController = Get.find<HomeController>();
  final TextEditingController codeController = TextEditingController();
  final RxBool isSubmitting = false.obs;

  Future<void> submitCode() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      ShamraSnackBar.show(
        context: context,
        message: 'بيانات غير مكتملة: يرجى إدخال الكود أولاً',
        type: SnackBarType.warning,
      );
      return;
    }

    isSubmitting.value = true;

    try {
      final result = await homeController.redeemEnrollmentCode(code);

      Get.back();

      ShamraSnackBar.show(
        context: context,
        message: result['message'] ?? (result['success'] ? 'تم التسجيل بنجاح' : 'فشل التحقق من الكود'),
        type: result['success'] ? SnackBarType.success : SnackBarType.error,
      );

      if (result['success'] == true && onUnlocked != null) {
        await onUnlocked();
      }
    } catch (e) {
      Get.back();

      ShamraSnackBar.show(
        context: context,
        message: 'حدث خطأ أثناء التحقق من الكود',
        type: SnackBarType.error,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ColorTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline, color: ColorTheme.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'هذا الكورس مقفول',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'أدخل كود الالتحاق أو امسح رمز QR للمتابعة',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => TextField(
                  controller: codeController,
                  textDirection: TextDirection.rtl,
                  textInputAction: TextInputAction.done,
                  enabled: !isSubmitting.value,
                  onSubmitted: (_) => submitCode(),
                  decoration: InputDecoration(
                    labelText: 'كود الالتحاق',
                    hintText: 'ادخل الكود هنا',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                )),
            SizedBox(height: 12),
            Obx(() => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSubmitting.value
                            ? null
                            : () async {
                                Get.back();
                                await Get.toNamed('/qr-scanner', parameters: {
                                  'courseId': courseId,
                                });
                                if (onUnlocked != null) {
                                  await onUnlocked();
                                }
                              },
                        icon: Icon(Icons.qr_code_scanner),
                        label: Text('مسح QR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColorTheme.primary,
                          side: BorderSide(color: ColorTheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting.value ? null : submitCode,
                        icon: isSubmitting.value
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.check_circle_outline),
                        label: Text(isSubmitting.value ? 'جاري التحقق...' : 'إدخال الكود'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorTheme.primary,
                        ),
                      ),
                    ),
                  ],
                )),
            TextButton(
              onPressed: () => Get.back(),
              child: Text('إلغاء'),
            )
          ],
        ),
      ),
    ),
    barrierDismissible: true,
  );
}
