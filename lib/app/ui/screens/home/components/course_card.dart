import 'package:flutter/material.dart';
import '../../../../data/models/course.dart';
import '../../../global_widgets/network_cover_image.dart';
import '../../../theme/color_theme.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final VoidCallback? onUnlockTap;
  final bool isEnrolled;
  final bool isAvailable;

  const CourseCard({
    Key? key,
    required this.course,
    required this.onTap,
    this.onUnlockTap,
    this.isEnrolled = false,
    this.isAvailable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDarkMode ? ColorTheme.darkCardBackground : Colors.white,
              border: Border.all(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Main content
                  _buildMainContent(context, theme, isDarkMode),
                  
                  // Enrolled badge
                  if (isEnrolled && isAvailable) _buildEnrolledBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ThemeData theme, bool isDarkMode) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and category
          _buildHeader(context, isDarkMode),
          
          SizedBox(height: 20),
          
          // Course title
          _buildTitle(theme, isDarkMode),
          
          SizedBox(height: 12),
          
          // Course description
          _buildDescription(theme, isDarkMode),
          
          SizedBox(height: 20),
          
          // Course metadata
          _buildMetadata(context, isDarkMode),

          if (!isAvailable) ...[
            SizedBox(height: 16),
            _buildLockedStrip(),
          ],
          
          // Progress section (only for enrolled courses)
          if (isEnrolled && isAvailable) ...[
            SizedBox(height: 24),
            _buildProgressSection(theme, isDarkMode),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: NetworkCoverImage(
              url: course.coverSmallUrl,
              cacheKey: course.coverSmall,
              fallback: Container(
                color: _getCourseColor(),
                child: Icon(
                  _getCourseIcon(),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        
        SizedBox(width: 12),
        
        // Category and level info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCourseColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(          
                  course.name,
                  style: TextStyle(
                    color: _getCourseColor(),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(ThemeData theme, bool isDarkMode) {
    return Text(
      course.name,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : Colors.grey[900],
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription(ThemeData theme, bool isDarkMode) {
    return Text(
      course.description,
      style: TextStyle(
        fontSize: 14,
        color: isDarkMode ? Colors.white70 : Colors.grey[600],
        height: 1.5,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetadata(BuildContext context, bool isDarkMode) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildMetadataChip(
          icon: Icons.calendar_month_outlined,
          label: 'الفصل: ${course.semester}',
          isDarkMode: isDarkMode,
        ),
        _buildMetadataChip(
          icon: Icons.school_outlined,
          label: 'السنة: ${course.yearLevel}',
          isDarkMode: isDarkMode,
        ),
        _buildMetadataChip(
          icon: Icons.person_outline,
          label: course.displayTeacherName,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.white.withOpacity(0.08)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme, bool isDarkMode) {
    final progress = _getRandomProgress();
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : _getCourseColor().withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : _getCourseColor().withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: _getCourseColor(),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'نسبة الإكمال',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCourseColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$progress%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getCourseColor(),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 10),
          
          // Progress bar
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getCourseColor(),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockedStrip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: Colors.orange[700], size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الكورس مقفل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
                SizedBox(height: 2),
                Text(
                  'أول محاضرة مجانية، فعّل الكورس لمشاهدة الباقي',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          if (onUnlockTap != null)
            TextButton(
              onPressed: onUnlockTap,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: ColorTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 14),
                minimumSize: Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('تفعيل', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildEnrolledBadge() {
    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 14,
            ),
            SizedBox(width: 4),
            Text(
              'مسجل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Color system based on course category
  Color _getCourseColor() {
    final String courseName = course.name.toLowerCase();
    
    if (courseName.contains('رياض') || courseName.contains('حساب') || 
        courseName.contains('إحصاء') || courseName.contains('خوارزميات')) {
      return Color(0xFF6366F1); // Indigo
    } else if (courseName.contains('فيزياء') || courseName.contains('علوم')) {
      return Color(0xFF8B5CF6); // Purple
    } else if (courseName.contains('برمج') || courseName.contains('حاسب') || 
               courseName.contains('كمبيوتر') || courseName.contains('ويب')) {
      return Color(0xFF0EA5E9); // Sky blue
    } else if (courseName.contains('أدب') || courseName.contains('لغة')) {
      return Color(0xFFEC4899); // Pink
    } else if (courseName.contains('تاريخ')) {
      return Color(0xFFF59E0B); // Amber
    } else if (courseName.contains('فن') || courseName.contains('رسم')) {
      return Color(0xFFEF4444); // Red
    } else if (courseName.contains('معالج') || courseName.contains('تشغيل') ||
               courseName.contains('صورة') || courseName.contains('تحكم')) {
      return Color(0xFF10B981); // Emerald
    } else if (courseName.contains('بيانية') || courseName.contains('حيوية') ||
               courseName.contains('ذكاء')) {
      return Color(0xFF14B8A6); // Teal
    } else if (courseName.contains('منطقية') || courseName.contains('نظرية') ||
               courseName.contains('زمن')) {
      return Color(0xFFF97316); // Orange
    } else {
      return ColorTheme.primary;
    }
  }



  IconData _getCourseIcon() {
    final String courseName = course.name.toLowerCase();

    if (courseName.contains('رياض') || courseName.contains('حساب') || 
        courseName.contains('إحصاء') || courseName.contains('خوارزميات')) {
      return Icons.functions_rounded;
    } else if (courseName.contains('فيزياء') || courseName.contains('علوم')) {
      return Icons.science_rounded;
    } else if (courseName.contains('برمج') || courseName.contains('حاسب') || 
               courseName.contains('كمبيوتر')) {
      return Icons.code_rounded;
    } else if (courseName.contains('ويب')) {
      return Icons.language_rounded;
    } else if (courseName.contains('أدب') || courseName.contains('لغة')) {
      return Icons.menu_book_rounded;
    } else if (courseName.contains('تاريخ')) {
      return Icons.history_edu_rounded;
    } else if (courseName.contains('فن') || courseName.contains('رسم')) {
      return Icons.palette_rounded;
    } else if (courseName.contains('معالج')) {
      return Icons.memory_rounded;
    } else if (courseName.contains('تشغيل')) {
      return Icons.settings_rounded;
    } else if (courseName.contains('صورة')) {
      return Icons.image_rounded;
    } else if (courseName.contains('تحكم')) {
      return Icons.settings_input_component_rounded;
    } else if (courseName.contains('بيانية')) {
      return Icons.account_tree_rounded;
    } else if (courseName.contains('ذكاء')) {
      return Icons.psychology_rounded;
    } else if (courseName.contains('حيوية')) {
      return Icons.biotech_rounded;
    } else if (courseName.contains('منطقية')) {
      return Icons.developer_board_rounded;
    } else if (courseName.contains('نظرية')) {
      return Icons.auto_stories_rounded;
    } else {
      return Icons.school_rounded;
    }
  }


  int _getRandomProgress() {
    return 30 + (course.name.hashCode % 70).abs();
  }
}
