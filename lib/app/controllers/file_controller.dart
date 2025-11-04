import 'package:course_platform/utils/helpers.dart';
import 'package:get/get.dart';
import '../data/repositories/file_repository.dart';
import '../data/models/file.dart';
import '../services/media_service.dart';

class FileController extends GetxController {
  final FileRepository _fileRepository;
  final MediaService _mediaService;

  FileController({
    required FileRepository fileRepository,
    required MediaService mediaService,
  })  : _fileRepository = fileRepository,
        _mediaService = mediaService;

  Rx<CourseFile?> currentFile = Rx<CourseFile?>(null);
  RxBool isLoading = true.obs;
  RxBool isDownloading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final String? fileId = Get.parameters['fileId'];
    if (fileId != null) {
      loadFile(fileId);
    }
  }

  Future<void> loadFile(String fileId) async {
    try {
      isLoading.value = true;
      currentFile.value = await _fileRepository.getFileDetails(fileId);
    } catch (e) {
      Helpers.showErrorSnackbar(
        'خطأ',
        'حدث خطأ أثناء تحميل الملف',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> downloadAndOpenFile() async {
    if (currentFile.value == null) return;

    try {
      isDownloading.value = true;
      // Use new method that gets signed URL from backend
      await _mediaService.downloadAndOpenFileById(
        currentFile.value!.id,
        '${currentFile.value!.title}.${currentFile.value!.fileType}',
      );
    } catch (e) {
      Helpers.showErrorSnackbar(
        'خطأ',
        'حدث خطأ أثناء تنزيل الملف',
      );
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> saveFile() async {
    if (currentFile.value == null) return;

    try {
      isDownloading.value = true;
      // Use new method that gets signed URL from backend
      final String? savedPath = await _mediaService.downloadFileById(
        currentFile.value!.id,
        '${currentFile.value!.title}.${currentFile.value!.fileType}',
      );

      if (savedPath != null) {
        Helpers.showSuccessSnackbar(
          'تم بنجاح',
          'تم حفظ الملف في المستندات',
        );
      }
    } catch (e) {
      Helpers.showErrorSnackbar(
        'خطأ',
        'حدث خطأ أثناء حفظ الملف',
      );
    } finally {
      isDownloading.value = false;
    }
  }
}
