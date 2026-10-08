import 'package:get/get.dart';
import 'package:dio/dio.dart' as p;
import '../../services/network_service.dart';

class AdProvider {
  final NetworkService _networkService = Get.find<NetworkService>();

  Future<p.Response> getAds() async {
    try {
      return await _networkService.get('/ads');
    } catch (e) {
      rethrow;
    }
  }
}
