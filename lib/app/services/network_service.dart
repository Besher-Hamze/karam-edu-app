import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import 'package:dio/dio.dart' as p;
import 'dart:math';

class NetworkService extends GetxService {
  late Dio _dio;
  final StorageService _storageService = Get.find<StorageService>();
  final String baseUrl = 'http://62.171.153.198:3050';
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Getter for dio instance
  Dio get dio => _dio;

  // Private variables for device information
  String? _deviceManufacturer;
  String? _deviceModel;
  int? _sdkVersion;
  bool? _isSamsungDevice;

  Future<NetworkService> init() async {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _storageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          _storageService.clearAllData();
          Get.offAllNamed('/login');
          Get.snackbar('خطأ في المصادقة', 'الرجاء تسجيل الدخول مرة أخرى',
              snackPosition: SnackPosition.BOTTOM);
        }
        return handler.next(e);
      },
    ));

    // Initialize device info
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      _deviceManufacturer = androidInfo.manufacturer?.toLowerCase() ?? "";
      _deviceModel = androidInfo.model ?? "";
      _sdkVersion = androidInfo.version.sdkInt ?? 0;
      _isSamsungDevice = _deviceManufacturer!.contains('samsung');

      print('Device: ${androidInfo.manufacturer} ${androidInfo.model}');
      print('Android SDK: $_sdkVersion');
      print('Is Samsung device: $_isSamsungDevice');
    }

    return this;
  }

  // GET Request
  Future<p.Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // POST Request
  Future<p.Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // PUT Request
  Future<p.Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // PATCH Request
  Future<p.Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // DELETE Request
  Future<p.Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // Multipart Request للملفات
  Future<p.Response> uploadFile(String path, File file, String fileName, Map<String, dynamic> data) async {
    try {
      p.FormData formData = p.FormData.fromMap({
        ...data,
        'file': await p.MultipartFile.fromFile(file.path, filename: fileName),
      });
      return await _dio.post(path, data: formData);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // التعامل مع الأخطاء
  void _handleError(DioException e) {
    String errorMessage = 'حدث خطأ في الاتصال بالخادم';
    if (e.response != null) {
      if (e.response!.data is Map && e.response!.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      } else {
        errorMessage = 'خطأ: ${e.response!.statusCode}';
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      errorMessage = 'انتهت مهلة الاتصال بالخادم';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage = 'تعذر الاتصال بالخادم، تحقق من اتصالك بالإنترنت';
    }

    Get.snackbar('خطأ', errorMessage, snackPosition: SnackPosition.BOTTOM);
  }

  // Generate a secure random filename that doesn't look like a video
  String _generateSecureFilename() {
    // List of common non-video extensions
    final extensions = ['.dat', '.bin', '.db', '.enc', '.data'];

    // Random length between 8-12 characters
    final random = Random();
    final length = random.nextInt(5) + 8;

    // Generate a random string
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final randomString = List.generate(
        length,
            (index) => chars[random.nextInt(chars.length)]
    ).join();

    // Add timestamp for uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Pick a random extension
    final extension = extensions[random.nextInt(extensions.length)];

    return '$randomString-$timestamp$extension';
  }

  // Find all available private storage directories that work on Samsung
  Future<List<Directory>> _getAvailablePrivateDirectories() async {
    final List<Directory> availableDirs = [];
    final List<Directory?> potentialDirs = [];

    try {
      // App-specific directories that should always be available without permissions
      potentialDirs.add(await getApplicationDocumentsDirectory());
      potentialDirs.add(await getApplicationCacheDirectory());
      potentialDirs.add(await getApplicationSupportDirectory());
      potentialDirs.add(await getTemporaryDirectory());

      // Test each directory
      for (var dir in potentialDirs) {
        if (dir == null) continue;

        try {
          // Check if directory exists and is writable
          final testFile = File('${dir.path}/test_write.tmp');
          await testFile.writeAsString('test');
          await testFile.delete();

          // If we get here, it's writable
          availableDirs.add(dir);
        } catch (e) {
          print('Directory ${dir.path} is not writable: $e');
        }
      }
    } catch (e) {
      print('Error finding available directories: $e');
    }

    return availableDirs;
  }

  // Get best directory for storing videos on Samsung devices
  Future<Directory?> _getBestVideoDirectory() async {
    try {
      // Get all available directories
      final availableDirs = await _getAvailablePrivateDirectories();

      if (availableDirs.isEmpty) {
        throw Exception('No writable directories found');
      }

      // Sort directories by available space (largest first)
      final dirWithSpace = <Directory, int>{};

      for (var dir in availableDirs) {
        try {
          if (_isSamsungDevice! && dir.path.contains('cache')) {
            // Skip cache directories for Samsung as they can be purged
            continue;
          }

          // Create a videos subdirectory
          final videosDir = Directory('${dir.path}/data_files');
          if (!await videosDir.exists()) {
            await videosDir.create(recursive: true);
          }

          // Check available space
          final stat = await File('${videosDir.path}/space_check.tmp').writeAsString('test');
          await stat.delete();

          // Directory works, add it
          dirWithSpace[videosDir] = await _getAvailableSpace(dir);
        } catch (e) {
          print('Error checking directory ${dir.path}: $e');
        }
      }

      if (dirWithSpace.isEmpty) {
        throw Exception('No writable video directories found');
      }

      // Return the directory with the most space
      final bestDir = dirWithSpace.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      print('Selected best directory for videos: ${bestDir.path}');
      return bestDir;
    } catch (e) {
      print('Error finding best video directory: $e');

      // Fallback to application documents directory
      try {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final videosDir = Directory('${fallbackDir.path}/data_files');
        if (!await videosDir.exists()) {
          await videosDir.create(recursive: true);
        }
        return videosDir;
      } catch (e2) {
        print('Error creating fallback directory: $e2');
        return null;
      }
    }
  }

  // Get available space in a directory (estimated)
  Future<int> _getAvailableSpace(Directory directory) async {
    try {
      // Try to create a 1MB file to test space
      final testFile = File('${directory.path}/space_test.tmp');

      // Create a buffer with 1MB
      final buffer = List<int>.filled(1024 * 1024, 0);
      await testFile.writeAsBytes(buffer);

      // Get file size to confirm
      final size = await testFile.length();
      await testFile.delete();

      // Directory has at least 1MB available
      return size;
    } catch (e) {
      print('Error checking available space: $e');
      return 0;
    }
  }

// Replace your downloadVideoPrivately method with this corrected version

  Future<String?> downloadVideoPrivately({
    required String videoUrl,
    required String videoId,
    required Function(int, int) onProgress,
    Function(String)? onStatusChange,
  }) async {
    print('========== ENHANCED VIDEO DOWNLOAD START ==========');
    print('Device: $_deviceManufacturer $_deviceModel (SDK $_sdkVersion)');
    print('Video ID: $videoId');
    print('Video URL: $videoUrl');

    String? downloadedFilePath;
    RandomAccessFile? raf;
    String? filePath;
    String? tempFilePath;
    int totalBytes = 0;

    try {
      // Get or create file path
      String? existingPath = await _storageService.getVideoPath(videoId);

      if (existingPath != null && existingPath.isNotEmpty) {
        filePath = existingPath;
        print('📁 Using existing path: $filePath');
      } else {
        final videoDir = await _getBestVideoDirectory();
        if (videoDir == null) {
          print('Error: No suitable directory found for storing videos');
          return null;
        }

        final secureFilename = _generateSecureFilename();
        filePath = '${videoDir.path}/$secureFilename';
        await _storageService.saveVideoPath(videoId, filePath);
        print('📁 Generated and saved new path: $filePath');
      }

      tempFilePath = '$filePath.tmp';
      print('📁 Temp file path: $tempFilePath');

      // Check if video is already completely downloaded
      final finalFile = File(filePath);
      if (await finalFile.exists()) {
        final size = await finalFile.length();
        if (size > 1024) { // More than 1KB means it's likely complete
          print('✅ Video already downloaded at: $filePath');
          onProgress(size, size);
          return filePath;
        } else {
          // File exists but is too small, delete it
          print('🗑️ Deleting incomplete final file');
          await finalFile.delete();
        }
      }

      // Check for partial download info
      final partialInfo = await _storageService.getPartialDownloadInfo(videoId);
      int startByte = 0;
      int savedTotalBytes = 0;

      if (partialInfo != null) {
        final savedDownloaded = partialInfo['downloadedBytes'] as int? ?? 0;
        savedTotalBytes = partialInfo['totalBytes'] as int? ?? 0;

        print('💾 Found saved progress: ${savedDownloaded / 1024 / 1024} MB / ${savedTotalBytes / 1024 / 1024} MB');

        // Validate saved progress - if totalBytes is 0 or invalid, clear it
        if (savedTotalBytes <= 0 || savedDownloaded <= 0) {
          print('⚠️ Invalid saved progress detected, clearing and starting fresh');
          await _storageService.removePartialDownloadInfo(videoId);
          startByte = 0;

          // Also delete temp file if it exists
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('🗑️ Deleted invalid temp file');
          }
        } else {
          // Check if temp file exists and matches saved progress
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            final actualSize = await tempFile.length();

            // Use the smaller of actual file size or saved progress for safety
            startByte = actualSize < savedDownloaded ? actualSize : savedDownloaded;

            if (startByte > 0) {
              print('🔄 Resuming download from byte: $startByte');
              totalBytes = savedTotalBytes; // Use saved total bytes
            } else {
              print('⚠️ Temp file exists but has 0 bytes, starting fresh');
              await tempFile.delete();
              await _storageService.removePartialDownloadInfo(videoId);
            }
          } else {
            print('⚠️ Partial info exists but no temp file found, starting fresh');
            await _storageService.removePartialDownloadInfo(videoId);
            startByte = 0;
          }
        }
      } else {
        print('🆕 No previous download found, starting fresh');
        startByte = 0;

        // Make sure no temp file exists
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
          print('🗑️ Deleted orphaned temp file');
        }
      }

      // Get auth token
      final token = _storageService.getToken();

      // Create Dio instance for downloading
      final Dio downloadDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 15),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Connection': 'keep-alive',
          'User-Agent': 'VideoDownloader/1.0',
          'Accept': '*/*',
          'Accept-Encoding': 'identity',
        },
      ));

      // Add range header for resume if needed
      if (startByte > 0) {
        downloadDio.options.headers['Range'] = 'bytes=$startByte-';
        print('📡 Request headers: Range=bytes=$startByte-');
      }

      onStatusChange?.call('connecting');
      print('🔌 Starting download request...');

      // Make the request
      final response = await downloadDio.get<ResponseBody>(
        videoUrl,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) {
            return status! < 400 || status == 416;
          },
        ),
      );

      if (response.data == null) {
        throw Exception('No response data received');
      }

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response headers: ${response.headers.map}');

      // Handle range not satisfiable
      if (response.statusCode == 416) {
        print('⚠️ Range not satisfiable - checking if file is complete');
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          final tempSize = await tempFile.length();
          if (tempSize > 1024) { // Reasonable size for a video
            await tempFile.rename(filePath);
            final finalSize = await finalFile.length();
            onProgress(finalSize, finalSize);
            await _storageService.removePartialDownloadInfo(videoId);
            return filePath;
          }
        }
        throw Exception('Range not satisfiable and no valid temp file exists');
      }

      // Parse content information
      final contentLength = response.headers.value('content-length');
      final contentRange = response.headers.value('content-range');

      // Determine total file size
      if (contentRange != null) {
        final rangeMatch = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
        if (rangeMatch != null) {
          final rangeStart = int.parse(rangeMatch.group(1)!);
          final rangeEnd = int.parse(rangeMatch.group(2)!);
          totalBytes = int.parse(rangeMatch.group(3)!);

          print('📊 Content-Range: $rangeStart-$rangeEnd/$totalBytes');

          if (rangeStart != startByte && rangeStart == 0) {
            print('⚠️ Server sending full file, restarting from beginning');
            final tempFile = File(tempFilePath);
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
            startByte = 0;
            await _storageService.removePartialDownloadInfo(videoId);
          }
        }
      } else if (contentLength != null) {
        final receivedLength = int.parse(contentLength);
        if (startByte > 0) {
          totalBytes = startByte + receivedLength;
        } else {
          totalBytes = receivedLength;
        }
      } else {
        throw Exception('Server did not provide content length information');
      }

      if (totalBytes <= 0) {
        throw Exception('Invalid total file size: $totalBytes');
      }

      print('📊 Total file size: ${totalBytes / 1024 / 1024} MB');
      print('📊 Starting from byte: $startByte');
      print('📊 Remaining to download: ${(totalBytes - startByte) / 1024 / 1024} MB');

      onStatusChange?.call('downloading');

      // Create temp file and open for writing
      final tempFile = File(tempFilePath);
      await tempFile.create(recursive: true);

      // Use append mode only if we're resuming, otherwise write mode
      raf = await tempFile.open(mode: startByte > 0 ? FileMode.append : FileMode.write);

      int downloadedBytes = startByte;
      int lastProgressUpdate = 0;
      int lastSaveTime = DateTime.now().millisecondsSinceEpoch;

      // Save initial progress with valid total bytes
      if (startByte == 0) {
        await _storageService.savePartialDownloadInfo(videoId, 0, totalBytes);
        print('💾 Saved initial progress: 0 MB / ${totalBytes / 1024 / 1024} MB');
      }

      // Download the file
      await for (final chunk in response.data!.stream) {
        await raf.writeFrom(chunk);
        downloadedBytes += chunk.length;

        // Update progress
        if (downloadedBytes - lastProgressUpdate >= 256 * 1024 ||
            downloadedBytes >= totalBytes) {
          onProgress(downloadedBytes, totalBytes);
          lastProgressUpdate = downloadedBytes;
        }

        // Save progress periodically
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - lastSaveTime >= 5000 || // Every 5 seconds
            downloadedBytes - lastProgressUpdate >= 5 * 1024 * 1024) { // Every 5MB
          await _storageService.savePartialDownloadInfo(videoId, downloadedBytes, totalBytes);
          lastSaveTime = currentTime;
        }

        // Log progress
        if (downloadedBytes % (1024 * 1024) < chunk.length) {
          final progress = downloadedBytes / totalBytes;
          print('📥 Download progress: ${(progress * 100).toStringAsFixed(1)}% ($downloadedBytes/$totalBytes bytes)');
        }
      }

      await raf.close();
      raf = null;

      // Verify download
      final finalSize = await tempFile.length();
      print('📁 Final temp file size: ${finalSize / 1024 / 1024} MB');

      if (finalSize < totalBytes) {
        throw Exception('Download incomplete: $finalSize/$totalBytes bytes');
      }

      // Move temp file to final location
      await tempFile.rename(filePath);
      downloadedFilePath = filePath;

      print('✅ Download complete. Final file size: ${finalSize / 1024 / 1024} MB');

      // Update storage
      await _storageService.saveVideoPath(videoId, filePath);
      await _storageService.addVideoToDownloadedList(videoId);
      await _storageService.removePartialDownloadInfo(videoId);

      onStatusChange?.call('completed');

    } catch (e, stackTrace) {
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }

      print('❌ Error downloading video: $e');
      print('📋 Stack trace: $stackTrace');
      onStatusChange?.call('error');

      // Save progress only if we have valid data
      if (downloadedFilePath == null && tempFilePath != null && totalBytes > 0) {
        try {
          final tempFile = File(tempFilePath);
          // Check if temp file exists before trying to get its length
          if (await tempFile.exists()) {
            final currentSize = await tempFile.length();
            if (currentSize > 0) {
              await _storageService.savePartialDownloadInfo(videoId, currentSize, totalBytes);
              print('💾 Saved current progress: ${currentSize / 1024 / 1024} MB');
            }
          } else {
            print('⚠️ Temp file does not exist, cannot save progress');
            // Clear any partial download info since temp file is missing
            await _storageService.removePartialDownloadInfo(videoId);
          }
        } catch (saveError) {
          print('Error saving progress on failure: $saveError');
          // If there's an error saving progress, clear partial download info to avoid corruption
          try {
            await _storageService.removePartialDownloadInfo(videoId);
          } catch (_) {}
        }
      }

      rethrow;
    }

    print('========== VIDEO DOWNLOAD ${downloadedFilePath != null ? "SUCCESS" : "FAILED"} ==========');
    return downloadedFilePath;
  }


  Future<bool> _validateDownloadedFile(String filePath, int expectedSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ Downloaded file does not exist: $filePath');
        return false;
      }

      final actualSize = await file.length();
      if (actualSize < expectedSize * 0.95) { // Allow 5% tolerance
        print('❌ Downloaded file size mismatch: $actualSize vs expected $expectedSize');
        return false;
      }

      print('✅ Downloaded file validation passed: ${actualSize / 1024 / 1024} MB');
      return true;
    } catch (e) {
      print('❌ Error validating downloaded file: $e');
      return false;
    }
  }
  Future<bool> canResumeDownload(String videoId) async {
    try {
      final partialInfo = await _storageService.getPartialDownloadInfo(videoId);
      if (partialInfo == null) return false;

      final existingPath = await _storageService.getVideoPath(videoId);
      if (existingPath == null) return false;

      final tempFile = File('$existingPath.tmp');
      return await tempFile.exists();
    } catch (e) {
      print('Error checking resume capability: $e');
      return false;
    }
  }

// Add this method to get download progress info
  Future<Map<String, dynamic>?> getDownloadInfo(String videoId) async {
    return await _storageService.getPartialDownloadInfo(videoId);
  }


  Future<bool> deletePrivateVideo(String videoId) async {
    try {
      // Get the file path from storage service
      final String? savedPath = await _storageService.getVideoPath(videoId);

      if (savedPath != null && savedPath.isNotEmpty) {
        final File videoFile = File(savedPath);
        if (await videoFile.exists()) {
          await videoFile.delete();

          // Remove from storage service
          await _storageService.saveVideoPath(videoId, '');
          await _storageService.removeVideoFromDownloadedList(videoId);

          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error deleting private video: $e');
      return false;
    }
  }

  Future<bool> isVideoDownloaded(String videoId) async {
    try {
      // Get the file path from storage service
      final String? savedPath = await _storageService.getVideoPath(videoId);

      if (savedPath != null && savedPath.isNotEmpty) {
        final File videoFile = File(savedPath);
        if (await videoFile.exists()) {
          final fileSize = await videoFile.length();
          return fileSize > 0;
        }
      }

      return false;
    } catch (e) {
      print('Error checking if video is downloaded: $e');
      return false;
    }
  }

  Future<String?> getPrivateVideoPath(String videoId) async {
    try {
      // Get the file path from storage service
      return await _storageService.getVideoPath(videoId);
    } catch (e) {
      print('Error getting private video path: $e');
      return null;
    }
  }

  String getVideoStreamUrl(String videoId, {bool download = false}) {
    return '$baseUrl/videos/stream/$videoId${download ? '?download=true' : ''}';
  }
}