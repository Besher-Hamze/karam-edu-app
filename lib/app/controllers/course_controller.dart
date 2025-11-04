import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/video_repository.dart';
import '../data/repositories/file_repository.dart';
import '../data/models/course.dart';
import '../data/models/video.dart';
import '../data/models/file.dart';
import '../services/storage_service.dart';
import '../routes/app_pages.dart';
import '../ui/global_widgets/snackbar.dart';

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

  // Public getter for file repository (needed for UI access)
  FileRepository get fileRepository => _fileRepository;

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

  // Watched videos tracking
  final RxMap<String, bool> watchedVideos = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDownloadedFilesList();
    _loadWatchedVideosList();

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

  // Initialize watched videos list from storage
  Future<void> _loadWatchedVideosList() async {
    final watchedList = await _storageService.getWatchedVideosList();
    for (String videoId in watchedList) {
      watchedVideos[videoId] = true;
    }
  }

  // Check if a video is watched
  bool isVideoWatched(String videoId) {
    return watchedVideos[videoId] ?? false;
  }

  // Public method to reload watched videos (for use in UI)
  Future<void> reloadWatchedVideos() async {
    await _loadWatchedVideosList();
  }

  Future<void> fetchCourseDetails(String courseId) async {
    try {
      isLoadingDetails.value = true;
      courseDetails.value = await _courseRepository.getCourseDetails(courseId);
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تحميل تفاصيل الكورس',
          type: SnackBarType.error,
        );
      }
    } finally {
      isLoadingDetails.value = false;
    }
  }

  Future<void> fetchCourseVideos(String courseId) async {
    try {
      isLoadingVideos.value = true;
      courseVideos.value = await _videoRepository.getVideosByCourse(courseId);
      // Reload watched status for the new videos
      await _loadWatchedVideosList();
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تحميل الفيديوهات',
          type: SnackBarType.error,
        );
      }
    } finally {
      isLoadingVideos.value = false;
    }
  }

  Future<void> fetchCourseFiles(String courseId) async {
    try {
      isLoadingFiles.value = true;
      courseFiles.value = await _fileRepository.getFilesByCourse(courseId);
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تحميل الملفات',
          type: SnackBarType.error,
        );
      }
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
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message: 'خطأ: تحتاج إلى منح إذن الوصول إلى التخزين',
            type: SnackBarType.error,
          );
        }
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
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء تنزيل الملف',
          type: SnackBarType.error,
        );
      }
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
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          final context = Get.context;
          if (context != null) {
            ShamraSnackBar.show(
              context: context,
              message: 'خطأ: لا يمكن فتح الملف. ${result.message}',
              type: SnackBarType.error,
            );
          }
        }
      }
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: حدث خطأ أثناء فتح الملف',
          type: SnackBarType.error,
        );
      }
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
    if (!Platform.isAndroid) {
      return true; // iOS always returns true
    }
    
    try {
      // For Android 13+ (API 33+), we use app's private storage which doesn't need permissions
      // Just verify we can write to private storage
      final directory = await getApplicationDocumentsDirectory();
      final testFile = File('${directory.path}/.permission_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      print('Error checking storage access: $e');
      
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: تعذر الوصول إلى التخزين',
          type: SnackBarType.error,
        );
      }
      return false;
    }
  }
}