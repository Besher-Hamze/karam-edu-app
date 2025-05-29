import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/profile_controller.dart';
import '../../theme/color_theme.dart';
import 'components/profile_form.dart';

class ProfileScreen extends GetView<ProfileController> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            // App bar with profile header
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: ColorTheme.primary,
              flexibleSpace: FlexibleSpaceBar(

                background: _buildProfileHeader(context),
              ),
            ),

            // Profile body content
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),

                    // Student info card
                    _buildStudentInfoCard(context),

                    SizedBox(height: 24),

                    // Profile form section
                    _buildProfileFormSection(context),

                    SizedBox(height: 24),

                    // Logout button
                    _buildLogoutButton(context),

                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // Profile header with avatar and student name
  Widget _buildProfileHeader(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                ColorTheme.primary,
                ColorTheme.primaryDark,
              ],
            ),
          ),
        ),

        // Pattern overlay (optional)
        Opacity(
          opacity: 0.1,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/pattern.png'),
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
        ),

        // Profile avatar and info
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (controller.student.value != null) ...[
                // Profile avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      controller.student.value!.fullName[0],
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: ColorTheme.primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Student name
                Text(
                  controller.student.value!.fullName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                // Student ID
                Text(
                  'الرقم الجامعي: ${controller.student.value!.universityId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Student information card
  Widget _buildStudentInfoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  color: ColorTheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'معلومات الطالب',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            if (controller.student.value != null) ...[
              _buildInfoRow(
                icon: Icons.person_outline,
                title: 'الاسم الكامل',
                value: controller.student.value!.fullName,
              ),
              SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.badge_outlined,
                title: 'الرقم الجامعي',
                value: controller.student.value!.universityId,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Profile form section
  Widget _buildProfileFormSection(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  color: ColorTheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'تعديل المعلومات الشخصية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ProfileForm(),
          ],
        ),
      ),
    );
  }

  // Logout button
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: controller.logout,
        icon: Icon(Icons.logout_rounded),
        label: Text(
          'تسجيل الخروج',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  // Helper method for info rows
  Widget _buildInfoRow({required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ColorTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: ColorTheme.primary,
            size: 18,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}