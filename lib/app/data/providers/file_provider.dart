import 'package:get/get.dart';
import '../../services/network_service.dart';
import 'package:dio/dio.dart' as p;

class FileProvider {
  final NetworkService _networkService = Get.find<NetworkService>();

  Future<p.Response> getFilesByCourse(String courseId) async {
    try {
      return await _networkService.get('/files/by-course/$courseId');
    } catch (e) {
      rethrow;
    }
  }

  Future<p.Response> getFileDetails(String fileId) async {
    try {
      return await _networkService.get('/files/$fileId');
    } catch (e) {
      rethrow;
    }
  }

  Future<p.Response> getFileUrl(String fileId) async {
    try {
      return await _networkService.get('/files/$fileId/url');
    } catch (e) {
      rethrow;
    }
  }
}
