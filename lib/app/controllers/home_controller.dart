import 'package:get/get.dart';
import '../data/repositories/course_repository.dart';
import '../data/models/course.dart';
import '../data/models/enrollment.dart';
import '../data/models/student.dart';
import '../services/storage_service.dart';

class HomeController extends GetxController {
  final CourseRepository _courseRepository;
  final StorageService _storageService;

  HomeController({
    required CourseRepository courseRepository,
    required StorageService storageService,
  })  : _courseRepository = courseRepository,
        _storageService = storageService;

  final RxList<Enrollment> enrolledCourses = <Enrollment>[].obs;
  final RxList<Course> availableCourses = <Course>[].obs;
  final RxBool isLoadingEnrolled = true.obs;
  final RxBool isLoadingAvailable = true.obs;
  final RxInt currentYear = 1.obs;
  final RxInt currentSemester = 1.obs;
  final RxString currentMajor = "حواسيب".obs;

  Rx<Student?> currentStudent = Rx<Student?>(null);

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
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تحميل الكورسات المتاحة',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingAvailable.value = false;
    }
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
}
