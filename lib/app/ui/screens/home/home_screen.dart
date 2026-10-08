import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/home_controller.dart';
import '../../theme/color_theme.dart';
import 'components/ads_carousel.dart';
import 'components/course_card.dart';
import 'components/semester_selector.dart';
import '../../global_widgets/unlock_course_dialog.dart';

class HomeScreen extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ColorTheme.primary,
        title: Text(
          'منصة التعلم',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(left: 16),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Get.toNamed('/profile'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            controller.fetchAvailableCourses(),
            controller.fetchAds(),
          ]);
        },
        color: ColorTheme.primary,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => controller.ads.isEmpty
                  ? SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: AdsCarousel(
                        ads: controller.ads.toList(),
                        onAdTap: controller.openAd,
                      ),
                    )),

              SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Semester Selector with enhanced styling
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SemesterSelector(
                        currentYear: controller.currentYear.value,
                        currentSemester: controller.currentSemester.value,
                        onYearChanged: controller.changeYear,
                        onSemesterChanged: controller.changeSemester,
                        currentMajor: controller.currentMajor.value,
                        onMajorChanged: controller.changeMajor,
                      ),
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              ),

              // Available Courses Section
              _buildSectionHeader(
                context,
                title: 'الكورسات المتاحة',
                icon: Icons.school_outlined,
              ),

              SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Obx(
                      () => controller.isLoadingAvailable.value
                      ? _buildLoadingIndicator()
                      : controller.availableCourses.isEmpty
                      ? _buildEmptyState(
                    'لا توجد كورسات متاحة',
                    'لا توجد كورسات متاحة للمستوى والفصل الدراسي المحدد',
                    Icons.search_off_outlined,
                  )
                      : Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: controller.availableCourses.length,
                        itemBuilder: (context, index) {
                          final course = controller.availableCourses[index];
                          final bool isAlreadyEnrolled =
                          controller.enrolledCourses.any(
                                (enrollment) => enrollment.course == course.id,
                          );

                          return CourseCard(
                            course: course,
                            onTap: () async {
                              await Get.toNamed(
                                '/course-detail',
                                parameters: {'courseId': course.id},
                              );
                              await controller.fetchAvailableCourses();
                            },
                            onUnlockTap: () => showUnlockCourseDialog(context, courseId: course.id),
                            isEnrolled: isAlreadyEnrolled,
                            isAvailable: course.isAvailable ?? false,
                          );
                        },
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced section header
  Widget _buildSectionHeader(BuildContext context,
      {required String title, required IconData icon}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ColorTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: ColorTheme.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced empty state
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Enhanced loading indicator
  Widget _buildLoadingIndicator() {
    return 
    Center(
      child: Container(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'جاري تحميل الكورسات...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'يرجى الانتظار قليلاً',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    ));
  }

}