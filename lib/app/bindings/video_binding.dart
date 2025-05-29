import 'package:get/get.dart';

import '../controllers/video_controller.dart';
import '../data/repositories/video_repository.dart';

class VideoBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VideoController>(() => VideoController(
          videoRepository: Get.find<VideoRepository>(),
        ));
  }
}
