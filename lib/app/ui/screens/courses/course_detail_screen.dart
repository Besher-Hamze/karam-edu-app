import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/course_controller.dart';
import '../../theme/color_theme.dart';
import 'components/video_list_item.dart';
import 'components/file_list_item.dart';
import 'package:course_platform/app/services/network_service.dart';

class CourseDetailScreen extends GetView<CourseController> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: RefreshIndicator(
        color: ColorTheme.primary,
        onRefresh: () async {
          final String? courseId = Get.parameters['courseId'];
          if (courseId != null) {
            await controller.fetchCourseDetails(courseId);
            await controller.fetchCourseVideos(courseId);
            await controller.fetchCourseFiles(courseId);
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
            ];
          },
          body: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course Details Card
                _buildCourseDetailsCard(context),

                SizedBox(height: 24),

                // Course Content Tabs
                _buildContentTabs(context),
              ],
            ),
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
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withOpacity(0.1),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCourseStat(
                    context,
                    icon: Icons.videocam_outlined,
                    value: '${controller.courseVideos.length}',
                    label: 'فيديو',
                  ),
                  _buildCourseStat(
                    context,
                    icon: Icons.insert_drive_file_outlined,
                    value: '${controller.courseFiles.length}',
                    label: 'ملف',
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab view for course content (videos and files)
  Widget _buildContentTabs(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: ColorTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[800],
              tabs: [
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('محاضرات الفيديو'),
                    ],
                  ),
                ),
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insert_drive_file_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('الملفات'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          Container(
            height: MediaQuery.of(context).size.height * 0.5, // Set to a percentage of screen height
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TabBarView(
              children: [
                // Videos Tab
                Obx(() => controller.isLoadingVideos.value
                    ? Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
                ))
                    : controller.courseVideos.isEmpty
                    ? _buildEmptyContentMessage(
                  'لا توجد فيديوهات لهذا الكورس',
                  'سيتم إضافة محاضرات الفيديو قريبًا',
                  Icons.videocam_off_outlined,
                )
                    : ListView.builder(
                  // Allow scrolling within the tab
                  physics: AlwaysScrollableScrollPhysics(),
                  // Don't use shrinkWrap as it can cause performance issues
                  shrinkWrap: false,
                  itemCount: controller.courseVideos.length,
                  itemBuilder: (context, index) {
                    final video = controller.courseVideos[index];
                    return VideoListItem(
                      video: video,
                      index: index + 1,
                      onTap: () => Get.toNamed(
                        '/video-player',
                        parameters: {'videoId': video.id},
                      ),
                      showDownloadOption: true,
                    );
                  },
                ),
                ),

                // Files Tab
                Obx(() => controller.isLoadingFiles.value
                    ? Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
                ))
                    : controller.courseFiles.isEmpty
                    ? _buildEmptyContentMessage(
                  'لا توجد ملفات لهذا الكورس',
                  'سيتم إضافة الملفات قريبًا',
                  Icons.folder_off_outlined,
                )
                    : ListView.builder(
                  // Allow scrolling within the tab
                  physics: AlwaysScrollableScrollPhysics(),
                  // Don't use shrinkWrap as it can cause performance issues
                  shrinkWrap: false,
                  itemCount: controller.courseFiles.length,
                  itemBuilder: (context, index) {
                    final file = controller.courseFiles[index];
                    return FileListItem(
                      file: file,
                      isDownloaded: controller.isFileDownloaded(file.id),
                      onTap: () async {
                        final isDownloaded = await controller.isFileDownloaded(file.id);
                        final String fileUrl = '${Get.find<NetworkService>().baseUrl}/${file.filePath}';

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
                                    await controller.downloadAndOpenFile(fileUrl, file);
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
            ),
          ),
        ],
      ),
    );
  }

  // Loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تحميل تفاصيل الكورس...',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            SizedBox(height: 24),
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
    );
  }

  // Empty content message
  Widget _buildEmptyContentMessage(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  int _calculateTotalDuration() {
    int totalMinutes = 0;
    for (var video in controller.courseVideos) {
      // Assuming video.durationInSeconds is available in the model
      // If not, you would need to parse the formatted duration
      totalMinutes += (40 ?? 0) ~/ 60;
    }
    return totalMinutes;
  }
}