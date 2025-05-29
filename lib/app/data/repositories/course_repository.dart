import '../providers/course_provider.dart';
import '../models/course.dart';
import '../models/enrollment.dart';

class CourseRepository {
  final CourseProvider _courseProvider;

  CourseRepository({required CourseProvider courseProvider}) : _courseProvider = courseProvider;

  Future<List<Enrollment>> getEnrolledCourses() async {
    try {
      final response = await _courseProvider.getEnrolledCourses();
      return (response.data as List).map((item) => Enrollment.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Course>> getCoursesByYearAndSemesterAndMajor(int year, int semester,String major) async {
    try {
      final response = await _courseProvider.getCoursesByYearAndSemester(year, semester,major);
      return (response.data as List).map((item) => Course.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Course> getCourseDetails(String courseId) async {
    try {
      final response = await _courseProvider.getCourseDetails(courseId);
      return Course.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }


}
