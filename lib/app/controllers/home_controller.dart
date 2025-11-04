import 'package:get/get.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/video_repository.dart';
import '../data/repositories/enrollment_repository.dart';
import '../data/models/course.dart';
import '../data/models/enrollment.dart';
import '../data/models/student.dart';
import '../services/storage_service.dart';
import '../ui/global_widgets/snackbar.dart';

class HomeController extends GetxController {
  final CourseRepository _courseRepository;
  final VideoRepository _videoRepository;
  final EnrollmentRepository _enrollmentRepository;
  final StorageService _storageService;

  HomeController({
    required CourseRepository courseRepository,
    required VideoRepository videoRepository,
    required EnrollmentRepository enrollmentRepository,
    required StorageService storageService,
  })  : _courseRepository = courseRepository,
        _videoRepository = videoRepository,
        _enrollmentRepository = enrollmentRepository,
        _storageService = storageService;

  final RxList<Enrollment> enrolledCourses = <Enrollment>[].obs;
  final RxList<Course> availableCourses = <Course>[].obs;
  final RxBool isLoadingEnrolled = true.obs;
  final RxBool isLoadingAvailable = true.obs;
  final RxInt currentYear = 1.obs;
  final RxInt currentSemester = 1.obs;
  final RxString currentMajor = "حواسيب".obs;

  Rx<Student?> currentStudent = Rx<Student?>(null);

  // Cache for course completion status
  final RxMap<String, bool> courseCompletionCache = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadStudentProfile();
    // fetchEnrolledCourses();
  }

  void loadStudentProfile() {
    final profileData = _storageService.getStudentProfile();
    if (profileData != null) {
      currentStudent.value = Student.fromJson(profileData);
      currentYear.value = 1;
      currentSemester.value = 1;

      fetchAvailableCourses();
    }
  }


  Future<void> fetchAvailableCourses() async {
    try {
      isLoadingAvailable.value = true;
      availableCourses.value =
          await _courseRepository.getCoursesByYearAndSemesterAndMajor(
              currentYear.value, currentSemester.value, currentMajor.value);
      // Check completion status for all courses
      await _checkCourseCompletions();
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تحميل الكورسات المتاحة',
          type: SnackBarType.error,
        );
      }
    } finally {
      isLoadingAvailable.value = false;
    }
  }

  // Check if all videos in a course are watched
  Future<bool> isCourseCompleted(String courseId) async {
    // Check cache first
    if (courseCompletionCache.containsKey(courseId)) {
      return courseCompletionCache[courseId] ?? false;
    }

    try {
      // Get all videos for the course
      final videos = await _videoRepository.getVideosByCourse(courseId);
      
      // If no videos, consider it not completed
      if (videos.isEmpty) {
        courseCompletionCache[courseId] = false;
        return false;
      }

      // Get watched videos list
      final watchedList = await _storageService.getWatchedVideosList();
      
      // Check if all videos are watched
      final allWatched = videos.every((video) => watchedList.contains(video.id));
      
      // Cache the result
      courseCompletionCache[courseId] = allWatched;
      
      return allWatched;
    } catch (e) {
      print('Error checking course completion: $e');
      return false;
    }
  }

  // Check completion status for all courses
  Future<void> _checkCourseCompletions() async {
    for (final course in availableCourses) {
      await isCourseCompleted(course.id);
    }
  }

  // Refresh completion status for a specific course
  Future<void> refreshCourseCompletion(String courseId) async {
    courseCompletionCache.remove(courseId);
    await isCourseCompleted(courseId);
  }

  void changeSemester(int semester) {
    currentSemester.value = semester;
    fetchAvailableCourses();
  }

  void changeYear(int year) {
    currentYear.value = year;
    fetchAvailableCourses();
  }

  void changeMajor(String major) {
    currentMajor.value = major;
    fetchAvailableCourses();
  }

  // Redeem enrollment code
  Future<Map<String, dynamic>> redeemEnrollmentCode(String code) async {
    try {
      final result = await _enrollmentRepository.redeemCode(code);
      
      if (result['success']) {
        // Refresh available courses after successful enrollment
        await fetchAvailableCourses();
      }
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'حدث خطأ أثناء التحقق من الكود',
      };
    }
  }
}
