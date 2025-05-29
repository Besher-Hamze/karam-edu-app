import 'package:get/get.dart';
import 'package:dio/dio.dart' as p;
import '../../services/network_service.dart';

class CourseProvider {
  final NetworkService _networkService = Get.find<NetworkService>();

  Future<p.Response> getEnrolledCourses() async {
    try {
      return await _networkService.get('/enrollments/by-student');
    } catch (e) {
      rethrow;
    }
  }

  Future<p.Response> getCoursesByYearAndSemester(int year, int semester,String major) async {
    try {
      return await _networkService.get('/courses/with-availability', queryParameters: {
        'year': year,
        'semester': semester,
        'major':major
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<p.Response> getCourseDetails(String courseId) async {
    try {
      return await _networkService.get('/courses/$courseId');
    } catch (e) {
      rethrow;
    }
  }


}

