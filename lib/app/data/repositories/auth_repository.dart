import '../providers/auth_provider.dart';
import '../models/student.dart';

class AuthRepository {
  final AuthProvider _authProvider;

  AuthRepository({required AuthProvider authProvider})
      : _authProvider = authProvider;

  Future<Map<String, dynamic>> login(
      String universityId, String password, String deviceNumber) async {
    try {
      final response =
          await _authProvider.login(universityId, password, deviceNumber);
      return {
        'accessToken': response.data['accessToken'],
        'student': Student.fromJson(response.data['student']),
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(String universityId, String fullName,
      String password, String deviceNumber) async {
    try {
      await _authProvider.register(
          universityId, fullName, password, deviceNumber);
      final loginResponse =
          await _authProvider.login(universityId, password, deviceNumber);
      return {
        'accessToken': loginResponse.data['accessToken'],
        'student': Student.fromJson(loginResponse.data['student']),
      };
    } catch (e) {
      rethrow;
    }
  }
}
