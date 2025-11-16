import 'package:get/get.dart';
import '../controllers/course_controller.dart';
import '../controllers/video_controller.dart';
import '../controllers/video_download_manager.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/video_repository.dart';
import '../data/repositories/file_repository.dart';
import '../data/providers/course_provider.dart';
import '../data/providers/video_provider.dart';
import '../data/providers/file_provider.dart';

class CourseBinding extends Bindings {
  @override
  void dependencies() {
    // Providers
    Get.lazyPut<CourseProvider>(() => CourseProvider());
    Get.lazyPut<VideoProvider>(() => VideoProvider());
    Get.lazyPut<VideoProvider>(() => VideoProvider());
    Get.lazyPut<FileProvider>(() => FileProvider());

    // Repositories
    Get.lazyPut<CourseRepository>(() => CourseRepository(courseProvider: Get.find<CourseProvider>()));
    Get.lazyPut<VideoRepository>(() => VideoRepository(videoProvider: Get.find<VideoProvider>()));
    Get.lazyPut<FileRepository>(() => FileRepository(fileProvider: Get.find<FileProvider>()));

    // Controllers
    Get.lazyPut<CourseController>(() => CourseController(
      courseRepository: Get.find<CourseRepository>(),
      videoRepository: Get.find<VideoRepository>(),
      fileRepository: Get.find<FileRepository>(),
    ));

    Get.lazyPut<VideoController>(() => VideoController(
      videoRepository: Get.find<VideoRepository>(),
    ));
    
    // Initialize VideoDownloadManager as permanent singleton (only once)
    if (!Get.isRegistered<VideoDownloadManager>()) {
      Get.put<VideoDownloadManager>(VideoDownloadManager(), permanent: true);
    }
  }
}
