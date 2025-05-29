import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../data/repositories/course_repository.dart';
import '../data/providers/course_provider.dart';
import '../services/storage_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CourseProvider>(() => CourseProvider());
    Get.lazyPut<CourseRepository>(() => CourseRepository(courseProvider: Get.find<CourseProvider>()));
    Get.lazyPut<HomeController>(() => HomeController(
      courseRepository: Get.find<CourseRepository>(),
      storageService: Get.find<StorageService>(),
    ));
  }
}
