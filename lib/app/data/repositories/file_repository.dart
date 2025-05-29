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
}
