import 'package:get/get.dart';
import 'package:dio/dio.dart' as p;
import '../../services/network_service.dart';

class StudentProvider {
  final NetworkService _networkService = Get.find<NetworkService>();

  Future<p.Response> getStudentProfile() async {
    try {
      return await _networkService.get('/students/my-infos');
    } catch (e) {
      rethrow;
    }
  }

  Future<p.Response> updateStudentProfile(String id, Map<String, dynamic> data) async {
    try {
      return await _networkService.patch('/students/$id', data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<p.Response> changePassword(String id, String oldPassword, String newPassword) async {
    try {
      return await _networkService.patch('/students/$id/change-password', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });
    } catch (e) {
      rethrow;
    }
  }
}
