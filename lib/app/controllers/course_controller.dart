import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/video_repository.dart';
import '../data/repositories/file_repository.dart';
import '../data/models/course.dart';
import '../data/models/video.dart';
import '../data/models/file.dart';
import '../services/storage_service.dart';
import '../routes/app_pages.dart';

class CourseController extends GetxController {
  final CourseRepository _courseRepository;
  final VideoRepository _videoRepository;
  final FileRepository _fileRepository;
  final StorageService _storageService = Get.find<StorageService>();
  final Dio _dio = Dio();

  CourseController({
    required CourseRepository courseRepository,
    required VideoRepository videoRepository,
    required FileRepository fileRepository,
  })  : _courseRepository = courseRepository,
        _videoRepository = videoRepository,
        _fileRepository = fileRepository;

  final Rx<Course?> courseDetails = Rx<Course?>(null);
  final RxList<Video> courseVideos = <Video>[].obs;
  final RxList<CourseFile> courseFiles = <CourseFile>[].obs;
  final RxBool isLoadingDetails = true.obs;
  final RxBool isLoadingVideos = true.obs;
  final RxBool isLoadingFiles = true.obs;

  // File download tracking
  final RxMap<String, bool> downloadingFiles = <String, bool>{}.obs;
  final RxMap<String, double> downloadProgress = <String, double>{}.obs;
  final RxMap<String, bool> downloadedFiles = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDownloadedFilesList();

    final String? courseId = Get.parameters['courseId'];
    if (courseId != null) {
      fetchCourseDetails(courseId);
      fetchCourseVideos(courseId);
      fetchCourseFiles(courseId);
    }
  }

  // Initialize downloaded files list from storage
  Future<void> _loadDownloadedFilesList() async {
    final downloadedList = await _storageService.getDownloadedFilesList();
    for (String fileId in downloadedList) {
      final filePath = await _storageService.getFilePath(fileId);
      if (filePath != null && await File(filePath).exists()) {
        downloadedFiles[fileId] = true;
      } else {
        // Remove from storage if file doesn't exist
        await _storageService.removeFileFromDownloadedList(fileId);
      }
    }
  }

  Future<void> fetchCourseDetails(String courseId) async {
    try {
      isLoadingDetails.value = true;
      courseDetails.value = await _courseRepository.getCourseDetails(courseId);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تحميل تفاصيل الكورس',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingDetails.value = false;
    }
  }

  Future<void> fetchCourseVideos(String courseId) async {
    try {
      isLoadingVideos.value = true;
      courseVideos.value = await _videoRepository.getVideosByCourse(courseId);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تحميل الفيديوهات',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingVideos.value = false;
    }
  }

  Future<void> fetchCourseFiles(String courseId) async {
    try {
      isLoadingFiles.value = true;
      courseFiles.value = await _fileRepository.getFilesByCourse(courseId);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تحميل الملفات',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingFiles.value = false;
    }
  }

  // Check if a file is downloaded
  bool isFileDownloaded(String fileId) {
    return downloadedFiles[fileId] ?? false;
  }

  // Get the local path for a downloaded file
  Future<String?> getLocalFilePath(String fileId) async {
    return await _storageService.getFilePath(fileId);
  }

  // Download a file and open it
  Future<void> downloadAndOpenFile(String fileUrl, CourseFile file) async {
    if (downloadingFiles[file.id] == true) return;

    try {
      downloadingFiles[file.id] = true;
      downloadProgress[file.id] = 0.0;

      // Check storage permission
      if (!await _requestStoragePermission()) {
        Get.snackbar(
          'خطأ',
          'تحتاج إلى منح إذن الوصول إلى التخزين',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${file.id}_${file.title}.${file.fileType}';

      // Download file with progress tracking
      await _dio.download(
        fileUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress[file.id] = received / total;
          }
        },
      );

      // Save file info to storage
      await _storageService.saveFilePath(file.id, filePath);
      await _storageService.addFileToDownloadedList(file.id);

      // Update downloaded status
      downloadedFiles[file.id] = true;

      // Open the file
      await openFile(filePath, file.fileType);

    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تنزيل الملف',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      downloadingFiles.remove(file.id);
      downloadProgress.remove(file.id);
    }
  }

  // Open a file with appropriate handler
  Future<void> openFile(String filePath, String fileType) async {
    try {
      if (fileType.toLowerCase() == 'pdf') {
        // Open PDF with PDF viewer
        Get.toNamed(Routes.PDF_VIEWER, arguments: {'filePath': filePath});
      } else {
        // Open other file types with system handler
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          Get.snackbar(
            'خطأ',
            'لا يمكن فتح الملف. ${result.message}',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء فتح الملف',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Delete a downloaded file
  Future<bool> deleteDownloadedFile(String fileId) async {
    try {
      final filePath = await _storageService.getFilePath(fileId);
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await _storageService.removeFileFromDownloadedList(fileId);
      downloadedFiles[fileId] = false;

      return true;
    } catch (e) {
      return false;
    }
  }

  // Request storage permission
  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    } else {
      final result = await Permission.storage.request();
      return result.isGranted;
    }
  }
}