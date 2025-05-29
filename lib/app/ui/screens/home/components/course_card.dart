import 'package:flutter/material.dart';
import '../../../../data/models/course.dart';
import '../../../theme/color_theme.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final bool isEnrolled;
  final bool isAvailable;

  const CourseCard({
    Key? key,
    required this.course,
    required this.onTap,
    this.isEnrolled = false,
    this.isAvailable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Generate a color based on the course name for the header decoration
    final int hashCode = course.name.hashCode;
    final Color headerColor = isEnrolled
        ? ColorTheme.primary
        : Color((hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(0.8);

    return Stack(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: isAvailable ? onTap : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course header with background color
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: headerColor.withOpacity(isAvailable ? 1 : 0.5),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Course icon
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(isAvailable ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCourseIcon(),
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),

                          // Course name
                          Expanded(
                            child: Text(
                              course.name,
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: isAvailable
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),

                          // Enrollment status
                          if (isEnrolled)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'مسجل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Course content
                    Container(
                      color: theme.cardColor.withOpacity(isAvailable ? 1 : 0.7),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Course details
                          Row(
                            children: [
                              _buildInfoChip(
                                context,
                                icon: Icons.school_outlined,
                                label: 'المستوى: ${course.yearLevel}',
                              ),
                              SizedBox(width: 12),
                              _buildInfoChip(
                                context,
                                icon: Icons.calendar_today_outlined,
                                label: 'الفصل: ${course.semester}',
                              ),
                            ],
                          ),
                          SizedBox(height: 12),

                          // Course description
                          Text(
                            course.description,
                            style: textTheme.bodyMedium?.copyWith(
                              color: isAvailable
                                  ? Colors.grey[700]
                                  : Colors.grey[500],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Progress indicator for enrolled courses
                          if (isEnrolled) ...[
                            SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'نسبة الإكمال',
                                      style: textTheme.labelMedium,
                                    ),
                                    Text(
                                      '${_getRandomProgress()}%',
                                      style: textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: ColorTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _getRandomProgress() / 100,
                                    backgroundColor: Colors.grey[200],
                                    color: ColorTheme.primary,
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Lock overlay for unavailable courses
        if (!isAvailable)
          Positioned.fill(
            child: Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.5),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'الكورس غير متاح',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'لا يمكنك الوصول إلى هذا الكورس حالياً',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getCourseIcon() {
    final String courseName = course.name.toLowerCase();

    if (courseName.contains('رياض') ||
        courseName.contains('حساب') ||
        courseName.contains('إحصاء')) {
      return Icons.calculate_outlined;
    } else if (courseName.contains('فيزياء') || courseName.contains('علوم')) {
      return Icons.science_outlined;
    } else if (courseName.contains('برمج') ||
        courseName.contains('حاسب') ||
        courseName.contains('كمبيوتر')) {
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

  // Mock function to generate random progress for enrolled courses
  // In a real app, this would come from the course data
  int _getRandomProgress() {
    return 30 + (course.name.hashCode % 70).abs();
  }

  Widget _buildInfoChip(BuildContext context,
      {required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey[700],
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
