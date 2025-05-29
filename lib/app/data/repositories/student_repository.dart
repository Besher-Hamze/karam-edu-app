import '../providers/student_provider.dart';
import '../models/student.dart';

class StudentRepository {
  final StudentProvider _studentProvider;

  StudentRepository({required StudentProvider studentProvider})
      : _studentProvider = studentProvider;

  Future<Student> getStudentProfile() async {
    try {
      final response = await _studentProvider.getStudentProfile();
      return Student.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Student> updateStudentProfile(String id, Map<String, dynamic> data) async {
    try {
      final response = await _studentProvider.updateStudentProfile(id, data);
      return Student.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword(String id, String oldPassword, String newPassword) async {
    try {
      await _studentProvider.changePassword(id, oldPassword, newPassword);
    } catch (e) {
      rethrow;
    }
  }
}
