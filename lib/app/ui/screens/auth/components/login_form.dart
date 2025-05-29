import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../utils/validators.dart';
import '../../../../controllers/auth_controller.dart';

class LoginForm extends GetView<AuthController> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // University ID field
          Text(
            'الرقم الجامعي',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: controller.universityIdController,
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
            controller: controller.passwordController,
            obscureText: controller.obscurePassword.value,
            decoration: InputDecoration(
              hintText: 'أدخل كلمة المرور',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscurePassword.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: controller.togglePasswordVisibility,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: Validators.required('كلمة المرور مطلوبة'),
            onFieldSubmitted: (_) => controller.login(),
          )),

          // Remember me checkbox
          SizedBox(height: 12),

          // Login button
          Obx(() => SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: controller.isLoading.value
                  ? null
                  : () => controller.login(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: controller.isLoading.value
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
                    'جاري تسجيل الدخول...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : Text(
                'تسجيل الدخول',
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