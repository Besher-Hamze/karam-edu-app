import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controllers/video_download_manager.dart';
import '../../../../data/models/video.dart';
import '../../../theme/color_theme.dart';

class VideoListItem extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final int? index;
  final bool isWatched;
  final bool showDownloadOption;

  const VideoListItem({
    Key? key,
    required this.video,
    required this.onTap,
    this.index,
    this.isWatched = false,
    this.showDownloadOption = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final downloadManager = Get.find<VideoDownloadManager>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.cardColor,
        border: Border.all(
          color: isWatched
              ? ColorTheme.primary.withOpacity(0.3)
              : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Content Row
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Play Button & Video Info
                  Expanded(
                    child: Row(
                      children: [
                        // Play Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                ColorTheme.primary,
                                ColorTheme.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: ColorTheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Video Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Lecture Number
                              if (index != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ColorTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'المحاضرة $index',
                                    style: TextStyle(
                                      color: ColorTheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),

                              // Video Title
                              Text(
                                video.title,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[900],
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4),

                              // Duration & Status Row
                              Row(
                                children: [
                                  // Duration Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          video.formattedDuration,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(width: 8),

                                  // Watched Status
                                  if (isWatched)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 12,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'تمت المشاهدة',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Download Section (if enabled)
          if (showDownloadOption)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: _buildDownloadSection(downloadManager),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection(VideoDownloadManager downloadManager) {
    return Obx(() {
      try {
        final status = downloadManager.getDownloadStatusString(video.id);
        final progress = downloadManager.downloadProgress[video.id] ?? 0.0;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: _buildDownloadStateWidget(downloadManager, status, progress),
        );
      } catch (e) {
        // Fallback to not started state if there's any error
        print('Error building download section: $e');
        return Padding(
          padding: const EdgeInsets.all(12),
          child: _buildNotStartedWidget(downloadManager),
        );
      }
    });
  }
  Widget _buildDownloadStateWidget(VideoDownloadManager downloadManager, String status, double progress) {
    switch (status) {
      case 'downloading':
        return _buildDownloadingWidget(downloadManager, progress);
      case 'paused':
        return _buildPausedWidget(downloadManager, progress);
      case 'completed':
        return _buildCompletedWidget(downloadManager);
      case 'error':
        return _buildErrorWidget(downloadManager);
      case 'connecting':
        return _buildConnectingWidget();
      default:
        return _buildNotStartedWidget(downloadManager);
    }
  }

// Replace your _buildDownloadingWidget method with this safe version:

  Widget _buildDownloadingWidget(VideoDownloadManager downloadManager, double progress) {
    // Ensure progress is a valid number between 0 and 1
    final safeProgress = _getSafeProgress(progress);
    final progressPercentage = _getSafeProgressPercentage(progress);

    return Row(
      children: [
        // Progress Circle
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: safeProgress,
                strokeWidth: 3,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              Text(
                '$progressPercentage%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 12),

        // Download Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جاري التحميل...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              LinearProgressIndicator(
                value: safeProgress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 4,
              ),
              SizedBox(height: 4),
              Text(
                '$progressPercentage% مكتمل',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 12),

        // Pause Button
        _buildActionButton(
          icon: Icons.pause,
          color: Colors.orange,
          onTap: () => downloadManager.pauseDownload(video.id),
          tooltip: 'إيقاف مؤقت',
        ),
      ],
    );
  }


  Widget _buildPausedWidget(VideoDownloadManager downloadManager, double progress) {
    // Ensure progress is a valid number between 0 and 1
    final safeProgress = _getSafeProgress(progress);
    final progressPercentage = _getSafeProgressPercentage(progress);

    return Row(
      children: [
        // Paused Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.pause_circle_filled,
            color: Colors.orange,
            size: 24,
          ),
        ),

        SizedBox(width: 12),

        // Download Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التحميل متوقف',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              LinearProgressIndicator(
                value: safeProgress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                minHeight: 4,
              ),
              SizedBox(height: 4),
              Text(
                '$progressPercentage% مكتمل - اضغط لاستئناف',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 8),

        // Resume Button
        _buildActionButton(
          icon: Icons.play_arrow,
          color: Colors.green,
          onTap: () => downloadManager.resumeDownload(video.id),
          tooltip: 'استئناف',
        ),

        SizedBox(width: 8),

        // Cancel Button
        _buildActionButton(
          icon: Icons.close,
          color: Colors.red,
          onTap: () => _showCancelDialog(downloadManager),
          tooltip: 'إلغاء',
        ),
      ],
    );
  }
  double _getSafeProgress(double progress) {
    if (progress.isNaN || progress.isInfinite || progress < 0) {
      return 0.0;
    }
    if (progress > 1.0) {
      return 1.0;
    }
    return progress;
  }

  /// Gets a safe progress percentage as an integer (0-100)
  int _getSafeProgressPercentage(double progress) {
    final safeProgress = _getSafeProgress(progress);
    final percentage = (safeProgress * 100);

    if (percentage.isNaN || percentage.isInfinite) {
      return 0;
    }

    return percentage.round().clamp(0, 100);
  }

  Widget _buildCompletedWidget(VideoDownloadManager downloadManager) {
    return Row(
      children: [
        // Success Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          ),
        ),

        SizedBox(width: 12),

        // Status Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم التحميل بنجاح',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'متاح للمشاهدة بدون إنترنت',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 12),

        // Delete Button
        _buildActionButton(
          icon: Icons.delete_outline,
          color: Colors.red,
          onTap: () => _showDeleteDialog(downloadManager),
          tooltip: 'حذف',
        ),
      ],
    );
  }

  Widget _buildErrorWidget(VideoDownloadManager downloadManager) {
    return Row(
      children: [
        // Error Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 24,
          ),
        ),

        SizedBox(width: 12),

        // Error Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'فشل في التحميل',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'تحقق من الاتصال واضغط لإعادة المحاولة',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 12),

        // Retry Button
        _buildActionButton(
          icon: Icons.refresh,
          color: Colors.blue,
          onTap: () => downloadManager.downloadVideo(video),
          tooltip: 'إعادة المحاولة',
        ),
      ],
    );
  }

  Widget _buildConnectingWidget() {
    return Row(
      children: [
        // Loading Spinner
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
          ),
        ),

        SizedBox(width: 12),

        // Connecting Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جاري الاتصال بالخادم...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorTheme.primary,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'يرجى الانتظار',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotStartedWidget(VideoDownloadManager downloadManager) {
    return FutureBuilder<bool>(
      future: downloadManager.canResumeDownload(video.id),
      builder: (context, snapshot) {
        final canResume = snapshot.data ?? false;

        return InkWell(
          onTap: () => downloadManager.downloadVideo(video),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Download Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ColorTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    canResume ? Icons.play_arrow : Icons.download,
                    color: ColorTheme.primary,
                    size: 24,
                  ),
                ),

                SizedBox(width: 12),

                // Download Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canResume ? 'استئناف التحميل' : 'تحميل للمشاهدة بدون إنترنت',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ColorTheme.primary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        canResume ? 'يمكن استكمال التحميل من حيث توقف' : 'اضغط لبدء التحميل',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 12),

                // Download Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: ColorTheme.primary,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(VideoDownloadManager manager) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'حذف الفيديو',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف الفيديو المحمل؟ ستحتاج إلى تحميله مرة أخرى للمشاهدة بدون إنترنت.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              manager.deleteDownloadedVideo(video.id);
              Get.back();
              Get.snackbar(
                'تم الحذف',
                'تم حذف الفيديو بنجاح',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
                duration: Duration(seconds: 2),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(VideoDownloadManager manager) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'إلغاء التحميل',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من إلغاء تحميل الفيديو؟ سيتم حذف الجزء المحمل وستحتاج لبدء التحميل من جديد.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('العودة', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              manager.cancelDownload(video.id);
              Get.back();
              Get.snackbar(
                'تم الإلغاء',
                'تم إلغاء تحميل الفيديو',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: Duration(seconds: 2),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('إلغاء التحميل'),
          ),
        ],
      ),
    );
  }
}