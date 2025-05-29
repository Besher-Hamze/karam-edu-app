import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../data/repositories/auth_repository.dart';
import '../data/providers/auth_provider.dart';
import '../services/storage_service.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthProvider>(() => AuthProvider());
    Get.lazyPut<AuthRepository>(() => AuthRepository(authProvider: Get.find<AuthProvider>()));
    Get.lazyPut<AuthController>(() => AuthController(
      authRepository: Get.find<AuthRepository>(),
      storageService: Get.find<StorageService>(),
    ));
  }
}
