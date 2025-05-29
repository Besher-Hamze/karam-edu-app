class CourseFile {
  final String id;
  final String title;
  final String description;
  final String filePath;
  final String course;
  final String fileType;
  final DateTime? createdAt;

  CourseFile({
    required this.id,
    required this.title,
    required this.description,
    required this.filePath,
    required this.course,
    required this.fileType,
    this.createdAt,
  });

  factory CourseFile.fromJson(Map<String, dynamic> json) {
    final filePath = json['filePath']?.toString() ?? '';
    final String processedPath;

    if (filePath.contains('\\')) {
      // Handle Windows-style paths with backslashes
      final parts = filePath.split('\\');
      processedPath = parts.length > 2 ? "uploads/files/${parts[2]}" : filePath;
    } else if (filePath.contains('/')) {
      // Handle Unix-style paths with forward slashes
      final parts = filePath.split('/');
      // Get the last part (filename)
      final fileName = parts.isNotEmpty ? parts.last : '';
      processedPath = "uploads/files/$fileName";
    } else {
      // If no slashes, use as is
      processedPath = "uploads/files/$filePath";
    }
    return CourseFile(
      id: json['_id'],
      title: json['title'],
      description: json['description'] ?? '',
      filePath: processedPath,
      course: json['course'],
      fileType: json['fileType'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  String get fileIcon {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'assets/icons/pdf.png';
      case 'doc':
      case 'docx':
        return 'assets/icons/doc.png';
      case 'ppt':
      case 'pptx':
        return 'assets/icons/ppt.png';
      case 'xls':
      case 'xlsx':
        return 'assets/icons/xls.png';
      default:
        return 'assets/icons/file.png';
    }
  }
}

