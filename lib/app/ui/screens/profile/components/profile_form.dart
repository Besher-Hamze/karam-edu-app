import 'package:course_platform/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controllers/profile_controller.dart';
import '../../../theme/color_theme.dart';

class ProfileForm extends GetView<ProfileController> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Info Section
          Text(
            'المعلومات الشخصية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ColorTheme.primary,
            ),
          ),
          SizedBox(height: 16),

          // Full Name Field
          _buildTextField(
            controller: controller.fullNameController,
            label: 'الاسم الكامل',
            hint: 'أدخل الاسم الكامل',
            icon: Icons.person_outline,
            validator: Validators.required('الاسم الكامل مطلوب'),
          ),
          SizedBox(height: 16),

          // Update Button
          _buildActionButton(
            context: context,
            label: 'تحديث المعلومات',
            isLoading: controller.isUpdating.value,
            onPressed: controller.updateProfile,
          ),

          Divider(height: 40, thickness: 1),


        ],
      ),
    );
  }

  // Custom text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    FormFieldValidator<String>? validator,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: ColorTheme.primary),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorTheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[400]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  // Action button
  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ColorTheme.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2,
          ),
        )
            : Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}