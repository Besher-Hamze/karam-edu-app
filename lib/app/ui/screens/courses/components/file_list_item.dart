import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/file.dart';
import '../../../theme/color_theme.dart';
import '../../../../controllers/course_controller.dart';

class FileListItem extends StatelessWidget {
  final CourseFile file;
  final VoidCallback onTap;
  final bool isDownloaded;


  const FileListItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.isDownloaded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final courseController = Get.find<CourseController>();

    return Obx(() {
      // Reactively check if file is downloaded
      final isFileDownloaded = courseController.downloadedFiles[file.id] ?? isDownloaded;
      
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFileDownloaded ? Colors.grey[300]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // File type icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getFileColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          file.fileType.toUpperCase(),
                          style: TextStyle(
                            color: _getFileColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Icon(
                          _getFileIcon(),
                          color: _getFileColor(),
                          size: 18,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 16),

                  // File details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 4),

                        if (file.description.isNotEmpty) ...[
                          Text(
                            file.description,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                        ],

                        // File size information
                        Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: 4),
                            Text(
                              _getFormattedDate(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Download button or Progress indicator
                  Builder(
                    builder: (context) {
                      final isDownloading = courseController.downloadingFiles[file.id] ?? false;
                      final progress = courseController.downloadProgress[file.id] ?? 0.0;

                      if (isDownloading) {
                        return SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ColorTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Container(
                          decoration: BoxDecoration(
                            color: isFileDownloaded ? Colors.grey[100] : ColorTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            isFileDownloaded ? Icons.check_circle_outline : Icons.download_outlined,
                            color: isFileDownloaded ? Colors.green[700] : ColorTheme.primary,
                            size: 24,
                          ),
                        );
                      }
                    },
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Color _getFileColor() {
    switch (file.fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red[700]!;
      case 'doc':
      case 'docx':
        return Colors.blue[700]!;
      case 'ppt':
      case 'pptx':
        return Colors.orange[700]!;
      case 'xls':
      case 'xlsx':
        return Colors.green[700]!;
      case 'zip':
      case 'rar':
        return Colors.purple[700]!;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.teal[700]!;
      case 'mp3':
      case 'wav':
        return Colors.amber[700]!;
      default:
        return ColorTheme.primary;
    }
  }

  IconData _getFileIcon() {
    switch (file.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }


  String _getFormattedDate() {
    // In a real app, this would come from the model's upload date
    // Here we're just generating a placeholder date
    final int day = (file.title.hashCode % 28) + 1;
    final int month = (file.title.hashCode % 12) + 1;
    final int year = 2023;

    return '$day/$month/$year';
  }
}