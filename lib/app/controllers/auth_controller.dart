import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../data/repositories/auth_repository.dart';
import '../services/storage_service.dart';
import '../ui/global_widgets/snackbar.dart';

class AuthController extends GetxController {
  AuthRepository _authRepository;
  StorageService _storageService;

  AuthController({
    required AuthRepository authRepository,
    required StorageService storageService,
  })  : _authRepository = authRepository,
        _storageService = storageService;

  // Login form controllers
  var formKey = GlobalKey<FormState>();
  RxBool isLoading = false.obs;
  RxBool obscurePassword = true.obs;

  // Register form controllers
  var registerFormKey = GlobalKey<FormState>();
  RxBool isRegisterLoading = false.obs;
  RxBool obscureRegisterPassword = true.obs;
  RxBool obscureConfirmPassword = true.obs;



  late TextEditingController universityIdController;
  late TextEditingController passwordController;
  late TextEditingController fullNameController;
  late TextEditingController registerUniversityIdController;
  late TextEditingController registerPasswordController;
  late TextEditingController confirmPasswordController;


  @override
  void onInit() {
    super.onInit();
    _initControllers();
  }

  void _initControllers() {
    universityIdController = TextEditingController();
    passwordController = TextEditingController();
    fullNameController = TextEditingController();
    registerUniversityIdController = TextEditingController();
    registerPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  void togglePasswordVisibility() =>
      obscurePassword.value = !obscurePassword.value;

  void toggleRegisterPasswordVisibility() =>
      obscureRegisterPassword.value = !obscureRegisterPassword.value;

  void toggleConfirmPasswordVisibility() =>
      obscureConfirmPassword.value = !obscureConfirmPassword.value;

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    try {
      isLoading.value = true;
      final String deviceNumber = await _getDeviceIdentifier();
      final result = await _authRepository.login(
          universityIdController.text.trim(),
          passwordController.text,
          deviceNumber);

      await _storageService.setToken(result['accessToken']);
      await _storageService.setStudentProfile(result['student'].toJson());
      Get.offAllNamed('/home');
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ في تسجيل الدخول: الرجاء التحقق من بيانات تسجيل الدخول',
          type: SnackBarType.error,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register() async {
    if (!registerFormKey.currentState!.validate()) return;

    if (registerPasswordController.text != confirmPasswordController.text) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ في كلمة المرور: كلمة المرور وتأكيد كلمة المرور غير متطابقين',
          type: SnackBarType.error,
        );
      }
      return;
    }

    try {
      isRegisterLoading.value = true;

      // Get device ID
      final String deviceNumber = await _getDeviceIdentifier();
      print(deviceNumber);
      final result = await _authRepository.register(
        registerUniversityIdController.text.trim(),
        fullNameController.text.trim(),
        registerPasswordController.text,
        deviceNumber,
      );

      await _storageService.setToken(result['accessToken']);
      await _storageService.setStudentProfile(result['student'].toJson());

      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'تم التسجيل بنجاح: تم إنشاء حسابك بنجاح',
          type: SnackBarType.success,
        );
      }

      Get.offAllNamed('/home');
    } catch (e) {
      print(e);
      String errorMessage = 'الرجاء التحقق من البيانات المدخلة';

      if (e.toString().contains('409')) {
        errorMessage = 'الرقم الجامعي مسجل بالفعل';
      }

      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ في التسجيل: $errorMessage',
          type: SnackBarType.error,
        );
      }
    } finally {
      isRegisterLoading.value = false;
    }
  }

  Future<String> _getDeviceIdentifier() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String identifier = '';

      if (GetPlatform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        identifier = androidInfo.id ?? ""; // Android device ID
      } else if (GetPlatform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        identifier = iosInfo.identifierForVendor ?? ''; // iOS identifier
      }
      print(identifier);
      return identifier.isNotEmpty ? identifier : 'unknown_device';
    } catch (e) {
      print('Error getting device identifier: $e');
      return 'unknown_device';
    }
  }

  // @override
  // void onClose() {
  //   // Dispose login controllers
  //   universityIdController.dispose();
  //   passwordController.dispose();
  //   fullNameController.dispose();
  //   registerUniversityIdController.dispose();
  //   registerPasswordController.dispose();
  //   confirmPasswordController.dispose();
  //
  //   super.onClose();
  // }
}
