import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/video_repository.dart';
import '../data/repositories/enrollment_repository.dart';
import '../data/repositories/ad_repository.dart';
import '../data/providers/course_provider.dart';
import '../data/providers/video_provider.dart';
import '../data/providers/enrollment_provider.dart';
import '../data/providers/ad_provider.dart';
import '../services/storage_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CourseProvider>(() => CourseProvider());
    Get.lazyPut<VideoProvider>(() => VideoProvider());
    Get.lazyPut<EnrollmentProvider>(() => EnrollmentProvider());
    Get.lazyPut<AdProvider>(() => AdProvider());
    Get.lazyPut<CourseRepository>(() => CourseRepository(courseProvider: Get.find<CourseProvider>()));
    Get.lazyPut<VideoRepository>(() => VideoRepository(videoProvider: Get.find<VideoProvider>()));
    Get.lazyPut<EnrollmentRepository>(() => EnrollmentRepository(enrollmentProvider: Get.find<EnrollmentProvider>()));
    Get.lazyPut<AdRepository>(() => AdRepository(adProvider: Get.find<AdProvider>()));
    Get.lazyPut<HomeController>(() => HomeController(
      courseRepository: Get.find<CourseRepository>(),
      videoRepository: Get.find<VideoRepository>(),
      enrollmentRepository: Get.find<EnrollmentRepository>(),
      adRepository: Get.find<AdRepository>(),
      storageService: Get.find<StorageService>(),
    ));
  }
}
