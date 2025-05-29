import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../utils/validators.dart';
import '../../../../controllers/auth_controller.dart';

class RegisterForm extends GetView<AuthController> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name field
          Text(
            'الاسم الكامل',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: controller.fullNameController,
            decoration: InputDecoration(
              hintText: 'أدخل الاسم الكامل',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: Validators.required('الاسم الكامل مطلوب'),
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: 20),

          // University ID field
          Text(
            'الرقم الجامعي',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: controller.registerUniversityIdController,
            decoration: InputDecoration(
              hintText: 'أدخل الرقم الجامعي',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: Validators.required('الرقم الجامعي مطلوب'),
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: 20),

          // Password field
          Text(
            'كلمة المرور',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          Obx(() => TextFormField(
            controller: controller.registerPasswordController,
            obscureText: controller.obscureRegisterPassword.value,
            decoration: InputDecoration(
              hintText: 'أدخل كلمة المرور',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscureRegisterPassword.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: controller.toggleRegisterPasswordVisibility,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: Validators.required('كلمة المرور مطلوبة'),
            textInputAction: TextInputAction.next,
          )),
          SizedBox(height: 20),

          // Confirm Password field
          Text(
            'تأكيد كلمة المرور',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          Obx(() => TextFormField(
            controller: controller.confirmPasswordController,
            obscureText: controller.obscureConfirmPassword.value,
            decoration: InputDecoration(
              hintText: 'أعد إدخال كلمة المرور',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscureConfirmPassword.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: controller.toggleConfirmPasswordVisibility,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value != controller.registerPasswordController.text) {
                return 'كلمة المرور غير متطابقة';
              }
              return null;
            },
            onFieldSubmitted: (_) => controller.register(),
          )),

          // Register button
          SizedBox(height: 30),
          Obx(() => SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: controller.isRegisterLoading.value
                  ? null
                  : () => controller.register(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: controller.isRegisterLoading.value
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'جاري التسجيل...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : Text(
                'تسجيل',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}