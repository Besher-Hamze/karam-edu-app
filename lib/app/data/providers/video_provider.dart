import 'package:get/get.dart';
import 'package:dio/dio.dart' as p;
import '../../services/network_service.dart';

class VideoProvider {
  final NetworkService _networkService = Get.find<NetworkService>();

  Future<p.Response> getVideosByCourse(String courseId) async {
    try {
      return await _networkService.get('/videos/by-course/$courseId');
    } catch (e) {
      rethrow;
    }
  }

  Future<p.Response> getVideoDetails(String videoId) async {
    try {
      return await _networkService.get('/videos/$videoId');
    } catch (e) {
      rethrow;
    }
  }
}
