import 'package:get/get.dart';
import '../controllers/profile_controller.dart';
import '../data/repositories/student_repository.dart';
import '../data/providers/student_provider.dart';
import '../services/storage_service.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StudentProvider>(() => StudentProvider());
    Get.lazyPut<StudentRepository>(() => StudentRepository(studentProvider: Get.find<StudentProvider>()));
    Get.lazyPut<ProfileController>(() => ProfileController(
      studentRepository: Get.find<StudentRepository>(),
      storageService: Get.find<StorageService>(),
    ));
  }
}
