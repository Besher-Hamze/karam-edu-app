import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/repositories/student_repository.dart';
import '../data/models/student.dart';
import '../services/storage_service.dart';

class ProfileController extends GetxController {
  final StudentRepository _studentRepository;
  final StorageService _storageService;

  ProfileController({
    required StudentRepository studentRepository,
    required StorageService storageService,
  })  : _studentRepository = studentRepository,
        _storageService = storageService;

  final Rx<Student?> student = Rx<Student?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isUpdating = false.obs;

  final formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadStudentData();
  }

  void loadStudentData() {
    final Map<String, dynamic>? profileData = _storageService.getStudentProfile();
    if (profileData != null) {
      student.value = Student.fromJson(profileData);
      fullNameController.text = student.value?.fullName ?? '';
    }
  }

  Future<void> updateProfile() async {
    if (!formKey.currentState!.validate()) return;

    try {
      isUpdating.value = true;

      if (student.value != null) {
        final updatedStudent = await _studentRepository.updateStudentProfile(
          student.value!.id,
          {'fullName': fullNameController.text.trim()},
        );

        student.value = updatedStudent;
        await _storageService.setStudentProfile(updatedStudent.toJson());

        Get.snackbar(
          'تم بنجاح',
          'تم تحديث المعلومات الشخصية بنجاح',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تحديث البيانات',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> changePassword() async {
    if (newPasswordController.text != confirmPasswordController.text) {
      Get.snackbar(
        'خطأ',
        'كلمات المرور الجديدة غير متطابقة',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isUpdating.value = true;

      if (student.value != null) {
        await _studentRepository.changePassword(
          student.value!.id,
          currentPasswordController.text,
          newPasswordController.text,
        );

        // مسح حقول كلمة المرور
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        Get.snackbar(
          'تم بنجاح',
          'تم تغيير كلمة المرور بنجاح',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تغيير كلمة المرور، تأكد من صحة كلمة المرور الحالية',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> logout() async {
    await _storageService.clearAllData();
    Get.offAllNamed('/login');
  }

  @override
  void onClose() {
    fullNameController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
