import 'package:get/get.dart';
import 'package:dio/dio.dart' as p;
import '../../services/network_service.dart';

class AuthProvider {
  final NetworkService _networkService = Get.find<NetworkService>();

  Future<p.Response> login(String universityId, String password,String deviceNumber) async {
    try {
      return await _networkService.post('/auth/login', data: {
        'universityId': universityId,
        'password': password,
        'deviceNumber':deviceNumber
      });
    } catch (e) {
      rethrow;
    }
  }
  Future<p.Response> register(String universityId, String fullName, String password, String deviceNumber) async {
    try {
      return await _networkService.post('/students', data: {
        'universityId': universityId,
        'fullName': fullName,
        'password': password,
        'deviceNumber': deviceNumber,
      });
    } catch (e) {
      rethrow;
    }
  }


}
