import '../providers/file_provider.dart';
import '../models/file.dart';

class FileRepository {
  final FileProvider _fileProvider;

  FileRepository({required FileProvider fileProvider}) : _fileProvider = fileProvider;

  Future<List<CourseFile>> getFilesByCourse(String courseId) async {
    try {
      final response = await _fileProvider.getFilesByCourse(courseId);
      return (response.data as List).map((item) => CourseFile.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CourseFile> getFileDetails(String fileId) async {
    try {
      final response = await _fileProvider.getFileDetails(fileId);
      return CourseFile.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // Get file URL from backend (signed URL)
  Future<String?> getFileUrl(String fileId) async {
    try {
      final response = await _fileProvider.getFileUrl(fileId);
      
      // Extract URL from response
      if (response.data != null) {
        // Check different possible response formats
        if (response.data is Map) {
          return response.data['url'] ?? response.data['fileUrl'] ?? response.data['downloadUrl'];
        } else if (response.data is String) {
          return response.data;
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting file URL: $e');
      return null;
    }
  }
}
