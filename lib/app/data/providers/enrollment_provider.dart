import 'package:get/get.dart';
import 'package:dio/dio.dart' as p;
import '../../services/network_service.dart';

class EnrollmentProvider {
  final NetworkService _networkService = Get.find<NetworkService>();

  Future<p.Response> redeemEnrollmentCode(String code) async {
    try {
      return await _networkService.post('/enrollments/redeem', data: {
        'code': code,
      });
    } catch (e) {
      rethrow;
    }
  }
}

