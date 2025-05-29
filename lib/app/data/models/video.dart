import 'course.dart';

class Video {
  final String id;
  final String title;
  final String description;
  final String filePath;
  final String courseId; // Renombrado para claridad
  final Course? courseDetails; // Objeto Course opcional
  final int? duration;
  final int? order;
  final DateTime? createdAt;

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.filePath,
    required this.courseId,
    this.courseDetails,
    this.duration,
    this.order,
    this.createdAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    final filePath = json['filePath']?.toString() ?? '';
    final String processedPath;

    if (filePath.contains('\\')) {
      // Handle Windows-style paths with backslashes
      final parts = filePath.split('\\');
      processedPath = parts.length > 2 ? "uploads/videos/${parts[2]}" : filePath;
    } else if (filePath.contains('/')) {
      // Handle Unix-style paths with forward slashes
      final parts = filePath.split('/');
      // Get the last part (filename)
      final fileName = parts.isNotEmpty ? parts.last : '';
      processedPath = "uploads/videos/$fileName";
    } else {
      // If no slashes, use as is
      processedPath = "uploads/videos/$filePath";
    }

    return Video(
      id: json['_id'],
      title: json['title'],
      description: json['description'] ?? '',
      filePath: processedPath,
      courseId: json['course'] is Map ? json['course']['_id'] : json['course'],
      courseDetails:
          json['course'] is Map ? Course.fromJson(json['course']) : null,
      duration: json['duration'],
      order: json['order'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'filePath': filePath,
      'course': courseDetails?.toJson() ?? courseId,
      'duration': duration,
      'order': order,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
  String get formattedDuration {
    if (duration == null) return '--:--';
    final minutes = (duration! / 60).floor();
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
