import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/course_controller.dart';
import '../../theme/color_theme.dart';
import '../../global_widgets/snackbar.dart';
import 'components/video_list_item.dart';
import 'components/file_list_item.dart';

class CourseDetailScreen extends GetView<CourseController> {
  @override
  Widget build(BuildContext context) {

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: RefreshIndicator(
          color: ColorTheme.primary,
          onRefresh: () async {
            final String? courseId = Get.parameters['courseId'];
            if (courseId != null) {
              await controller.fetchCourseDetails(courseId);
              await controller.fetchCourseVideos(courseId);
              await controller.fetchCourseFiles(courseId);
              await controller.reloadWatchedVideos();
            }
          },
          child: Obx(() => controller.isLoadingDetails.value && controller.courseDetails.value == null
              ? _buildLoadingState()
              : controller.courseDetails.value == null
              ? _buildErrorState()
              : NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildSliverAppBar(context),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCourseDetailsCard(context),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarHeaderDelegate(
                    child: _buildPinnedTabBar(context),
                    height: 60,
                  ),
                ),
              ];
            },
            body: _buildTabBarView(context),
          ),
          ),
        ),
      ),
    );
  }

  // Sliver App Bar with course image and back button
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: ColorTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Obx(() => Text(
          controller.courseDetails.value?.name ?? 'تفاصيل الكورس',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )),
        background: Stack(
          fit: StackFit.expand,
          children: [
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

            // Course icon overlay
            Center(
              child: Icon(
                _getCourseIcon(),
                size: 80,
                color: Colors.white.withOpacity(0.3),
              ),
            ),

            // Gradient overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                  stops: [0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Course details card
  Widget _buildCourseDetailsCard(BuildContext context) {
    final course = controller.courseDetails.value!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course level and semester info
              Row(
                children: [
                  _buildInfoChip(
                    context,
                    icon: Icons.school_outlined,
                    label: 'المستوى: ${course.yearLevel}',
                  ),
                  SizedBox(width: 8),
                  _buildInfoChip(
                    context,
                    icon: Icons.calendar_today_outlined,
                    label: 'الفصل: ${course.semester}',
                  ),
                ],
              ),

              SizedBox(height: 20),

              Divider(height: 1, color: Colors.grey[200]),
              SizedBox(height: 16),

              // Course description
              Text(
                'الوصف',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                course.description.isEmpty ? 'لا يوجد وصف متاح' : course.description,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),

              SizedBox(height: 20),

              // Course stats
              Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Obx(() => _buildCourseStat(
                          context,
                          icon: Icons.videocam_outlined,
                          value: '${controller.courseVideos.length}',
                          label: 'فيديو',
                        )),
                    Container(width: 1, height: 32, color: Colors.grey[300]),
                    Obx(() => _buildCourseStat(
                          context,
                          icon: Icons.insert_drive_file_outlined,
                          value: '${controller.courseFiles.length}',
                          label: 'ملف',
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // IMPROVED: Modern Card Style TabBar (Main Design)
  Widget _buildPinnedTabBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(4),
        child: TabBar(
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: ColorTheme.primary,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) {
                return ColorTheme.primary.withOpacity(0.1);
              }
              return null;
            },
          ),
          tabs: [
            Tab(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('محاضرات الفيديو'),
                ],
              ),
            ),
            Tab(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_drive_file_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('الملفات'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (Removed) Alternative TabBar designs: keeping single, clean implementation

  // TabBarView body with coordinated single scroll
  Widget _buildTabBarView(BuildContext context) {
    return TabBarView(
      children: [
        // Videos Tab
        Obx(() => controller.isLoadingVideos.value
            ? _buildSectionLoading()
            : controller.courseVideos.isEmpty
            ? _buildEmptyContentMessage(
                'لا توجد فيديوهات لهذا الكورس',
                'سيتم إضافة محاضرات الفيديو قريبًا',
                Icons.videocam_off_outlined,
              )
            : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: controller.courseVideos.length,
              itemBuilder: (context, index) {
                final video = controller.courseVideos[index];
                return Obx(() => VideoListItem(
                  video: video,
                  index: index + 1,
                  isWatched: controller.isVideoWatched(video.id),
                  onTap: () async {
                    // Navigate to video player
                    await Get.toNamed(
                      '/video-player',
                      parameters: {'videoId': video.id},
                    );
                    // Reload watched status after returning from video player
                    await controller.reloadWatchedVideos();
                  },
                  showDownloadOption: true,
                ));
              },
            ),
        ),

        // Files Tab
        Obx(() => controller.isLoadingFiles.value
            ? _buildSectionLoading()
            : controller.courseFiles.isEmpty
            ? _buildEmptyContentMessage(
                'لا توجد ملفات لهذا الكورس',
                'سيتم إضافة الملفات قريبًا',
                Icons.folder_off_outlined,
              )
            : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: controller.courseFiles.length,
              itemBuilder: (context, index) {
                final file = controller.courseFiles[index];
                return FileListItem(
                  file: file,
                  isDownloaded: controller.isFileDownloaded(file.id),
                  onTap: () async {
                    final isDownloaded = await controller.isFileDownloaded(file.id);

                    if (isDownloaded) {
                      final localPath = await controller.getLocalFilePath(file.id);
                      if (localPath != null) {
                        controller.openFile(localPath, file.fileType);
                      }
                    } else {
                      Get.dialog(
                        AlertDialog(
                          title: Text('تنزيل الملف'),
                          content: Text('هل تريد تنزيل هذا الملف؟'),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Get.back();
                                // Get signed URL from backend
                                final String? fileUrl = await controller.fileRepository.getFileUrl(file.id);
                                if (fileUrl != null) {
                                  await controller.downloadAndOpenFile(fileUrl, file);
                                } else {
                                  ShamraSnackBar.show(
                                    context: context,
                                    message: 'خطأ: فشل الحصول على رابط الملف',
                                    type: SnackBarType.error,
                                  );
                                }
                              },
                              child: Text('تنزيل'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                );
              },
            ),
        ),
      ],
    );
  }

  // Loading state
  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            SizedBox(height: 16),
            Text(
              'جاري تحميل تفاصيل الكورس...',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: ColorTheme.error,
                size: 60,
              ),
              SizedBox(height: 16),
              Text(
                'لا يمكن تحميل تفاصيل الكورس',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final String? courseId = Get.parameters['courseId'];
                  if (courseId != null) {
                    controller.fetchCourseDetails(courseId);
                    controller.fetchCourseVideos(courseId);
                    controller.fetchCourseFiles(courseId);
                  }
                },
                icon: Icon(Icons.refresh),
                label: Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorTheme.primary,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Empty content message
  Widget _buildEmptyContentMessage(String title, String subtitle, IconData icon) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLoading() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'جاري التحميل...'
            ),
          ],
        ),
      ),
    );
  }

  // Helper widgets

  Widget _buildInfoChip(BuildContext context, {required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: ColorTheme.primary,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseStat(BuildContext context, {required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ColorTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: ColorTheme.primary,
            size: 20,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Helper methods

  IconData _getCourseIcon() {
    final String courseName = controller.courseDetails.value?.name.toLowerCase() ?? '';

    if (courseName.contains('رياض') || courseName.contains('حساب') || courseName.contains('إحصاء')) {
      return Icons.calculate_outlined;
    } else if (courseName.contains('فيزياء') || courseName.contains('علوم')) {
      return Icons.science_outlined;
    } else if (courseName.contains('برمج') || courseName.contains('حاسب') || courseName.contains('كمبيوتر')) {
      return Icons.computer_outlined;
    } else if (courseName.contains('أدب') || courseName.contains('لغة')) {
      return Icons.book_outlined;
    } else if (courseName.contains('تاريخ')) {
      return Icons.history_edu_outlined;
    } else if (courseName.contains('فن') || courseName.contains('رسم')) {
      return Icons.palette_outlined;
    } else {
      return Icons.school_outlined;
    }
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _TabBarHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent,
      child: child,
    );
  }
  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
